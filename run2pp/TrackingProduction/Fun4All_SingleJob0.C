/*
 * This macro is run in our daily CI and is intended as a minimum working
 * example showing how to unpack the raw hits into the offline tracker hit
 * format. No other reconstruction or analysis is performed
 */
#include <QA.C>
#include <GlobalVariables.C>
#include <Trkr_Clustering.C>
#include <Trkr_LaserClustering.C>
#include <Trkr_RecoInit.C>

#include <fun4all/Fun4AllUtils.h>
#include <fun4all/Fun4AllDstInputManager.h>
#include <fun4all/Fun4AllDstOutputManager.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllOutputManager.h>
#include <fun4all/Fun4AllRunNodeInputManager.h>
#include <fun4all/Fun4AllServer.h>


#include <trackingqa/InttClusterQA.h>
#include <trackingqa/MicromegasClusterQA.h>
#include <trackingqa/MvtxClusterQA.h>
#include <trackingqa/TpcClusterQA.h>

#include <ffamodules/CDBInterface.h>
#include <ffamodules/FlagHandler.h>
#include <mvtxrawhitqa/MvtxRawHitQA.h>
#include <inttrawhitqa/InttRawHitQA.h>
#include <tpcqa/TpcRawHitQA.h>
#include <phool/recoConsts.h>

#include <stdio.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libffamodules.so)
R__LOAD_LIBRARY(libmvtx.so)
R__LOAD_LIBRARY(libintt.so)
R__LOAD_LIBRARY(libtpc.so)
R__LOAD_LIBRARY(libmicromegas.so)
R__LOAD_LIBRARY(libinttrawhitqa.so)
R__LOAD_LIBRARY(libmvtxrawhitqa.so)
R__LOAD_LIBRARY(libtpcqa.so)
R__LOAD_LIBRARY(libtrackingqa.so)
void Fun4All_SingleTrkrHitSet_Unpacker(
    const int nEvents = 2,
    const int runnumber = 41626,
    const std::string outfilename = "cosmics",
    const std::string dbtag = "2024p001",
    const std::string filelist = "filelist.list")
{

  gSystem->Load("libg4dst.so");
  //char filename[500];
  //sprintf(filename, "%s%08d-0000.root", inputRawHitFile.c_str(), runnumber);
 

  auto se = Fun4AllServer::instance();
  se->Verbosity(1);
  auto rc = recoConsts::instance();

  std::ifstream ifs(filelist);
  std::string filepath;


  if(runNumber>51428)
    {
      TRACKING::tpc_zero_supp = true;
    }

  CDBInterface::instance()->Verbosity(1);

  rc->set_StringFlag("CDB_GLOBALTAG", dbtag );
  rc->set_uint64Flag("TIMESTAMP", runnumber);

  FlagHandler *flag = new FlagHandler();
  se->registerSubsystem(flag);

  std::string geofile = CDBInterface::instance()->getUrl("Tracking_Geometry");
  Fun4AllRunNodeInputManager *ingeo = new Fun4AllRunNodeInputManager("GeoIn");
  ingeo->AddFile(geofile);
  se->registerInputManager(ingeo);
  
  TrackingInit();

  int i = 0;
  std::string filenum = "";
  
  while(std::getline(ifs,filepath))
    {
      
     if(i==0)
	{
	   std::pair<int, int> runseg = Fun4AllUtils::GetRunSegment(filepath);
	   int runNumber = runseg.first;
	   int segment = runseg.second;
	   rc->set_IntFlag("RUNNUMBER", runNumber);
	   rc->set_uint64Flag("TIMESTAMP", runNumber);
	   if(filepath.find("MVTX") != std::string::npos)
	     {
	       filenum = filepath.substr(filepath.find("MVTX")+4,1);
	     }
	   else if(filepath.find("INTT") != std::string::npos)
	     {
	       filenum = filepath.substr(filepath.find("INTT")+4,1);
	     }
	   else if (filepath.find("TPC") != std::string::npos)
	     {
	       filenum = filepath.substr(filepath.find("TPC")+3,2);
	     }
	   else if (filepath.find("TPOT") != std::string::npos)
	     {
	       // do nothing for TPOT since it processes together no matter what
	   
	     }
	}
      std::string inputname = "InputManager" + std::to_string(i);
      auto hitsin = new Fun4AllDstInputManager(inputname);
      hitsin->fileopen(filepath);
      se->registerInputManager(hitsin);
      i++;
    }
  
  for(int felix=0; felix < 6; felix++)
    {
      Mvtx_HitUnpacking(std::to_string(felix));
    }
  for(int server = 0; server < 8; server++)
    {
      Intt_HitUnpacking(std::to_string(filenum));
    }
  char buff[10];
  for(int ebdc = 0; ebdc < 24; ebdc++)
    {
      Tpc_HitUnpacking(std::string(sprintf(buff,"%02i", ebdc)));
    }

  Micromegas_HitUnpacking();

  Mvtx_Clustering();

  Intt_Clustering();

  Tpc_LaserEventIdentifying();

  TPC_LaserClustering();

  auto tpcclusterizer = new TpcClusterizer;
  tpcclusterizer->Verbosity(0);
  tpcclusterizer->set_do_hit_association(G4TPC::DO_HIT_ASSOCIATION);
  tpcclusterizer->set_rawdata_reco();
  tpcclusterizer->set_reject_event(G4TPC::REJECT_LASER_EVENTS);
  se->registerSubsystem(tpcclusterizer);

  Micromegas_Clustering();

  se->registerSubsystem(new MvtxClusterQA);
  se->registerSubsystem(new InttClusterQA);
  se->registerSubsystem(new TpcClusterQA);
  se->registerSubsystem(new MicromegasClusterQA);


  auto mvtx = new MvtxRawHitQA;
  se->registerSubsystem(mvtx);

  auto intt = new InttRawHitQA;
  se->registerSubsystem(intt);
  
  auto tpc = new TpcRawHitQA;
  se->registerSubsystem(tpc);

  Fun4AllOutputManager *out = new Fun4AllDstOutputManager("DSTOUT", outfilename);
  out->AddNode("Sync");
  out->AddNode("EventHeader");
  out->AddNode("TRKR_CLUSTER");
  out->AddNode("TRKR_CLUSTERCROSSINGASSOC");
  out->AddNode("LaserEventInfo");
  if(G4TPC::ENABLE_CENTRAL_MEMBRANE_CLUSTERING)
  {
    out->AddNode("LASER_CLUSTER");
  }
  se->registerOutputManager(out);

  se->run(nEvents);
  se->End();

  TString qaname = "HIST_" + outfilename;
  std::string qaOutputFileName(qaname.Data());
  QAHistManagerDef::saveQARootFile(qaOutputFileName);

  CDBInterface::instance()->Print();
  se->PrintTimer();

  delete se;
  std::cout << "Finished" << std::endl;
  gSystem->Exit(0);
}
