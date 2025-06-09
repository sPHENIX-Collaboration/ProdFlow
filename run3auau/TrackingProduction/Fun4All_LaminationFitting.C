/*
 * This macro shows a minimum working example of running the tracking
 * hit unpackers with some basic seeding algorithms to try to put together
 * tracks. There are some analysis modules run at the end which package
 * hits, clusters, and clusters on tracks into trees for analysis.
 */

#include <GlobalVariables.C>
#include <fun4all/Fun4AllUtils.h>
#include <G4_ActsGeom.C>
#include <Trkr_LaserClustering.C>
#include <Trkr_RecoInit.C>

#include <ffamodules/CDBInterface.h>
#include <fun4all/Fun4AllDstInputManager.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllRunNodeInputManager.h>
#include <fun4all/Fun4AllServer.h>

#include <phool/recoConsts.h>

//#include <tpc/LaserEventIdentifier.h>

#include <stdio.h>
R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libffamodules.so)
R__LOAD_LIBRARY(libtpc.so)
R__LOAD_LIBRARY(libtpccalib.so)
void Fun4All_LaminationFitting(
    const int nEvents = 2,
    const std::string dbtag = "2024p001",
    const std::string filelist = "filelist.list",
    const std::string outfile = "Laminations.root",
    const std::string QAfile = "Laminations_QA.pdf")
{

  gSystem->Load("libg4dst.so");
  
  auto se = Fun4AllServer::instance();
  se->Verbosity(5);
  auto rc = recoConsts::instance();
  CDBInterface::instance()->Verbosity(1);
  
  rc->set_StringFlag("CDB_GLOBALTAG", dbtag);

  std::ifstream ifs(filelist);
  std::string filepath;
  int i=0;
  int runnumber = 0;
  while(std::getline(ifs,filepath))
  {
    if(i==0)
    {
      std::pair<int, int> runseg = Fun4AllUtils::GetRunSegment(filepath);
      runnumber = runseg.first;
      rc->set_IntFlag("RUNNUMBER",runnumber);
      rc->set_uint64Flag("TIMESTAMP",runnumber);
    }

    //std::string inputname = "InputManager" + std::to_string(i);
    //auto hitsin = new Fun4AllDstInputManager(inputname);
    //hitsin->fileopen(filepath);
    //se->registerInputManager(hitsin);
    i++;
  }

  auto hitsin = new Fun4AllDstInputManager("InputManager");
  hitsin->AddListFile(filelist);
  se->registerInputManager(hitsin);
  
  TRACKING::tpc_zero_supp = true;
  Enable::MVTX_APPLYMISALIGNMENT = true;
  ACTSGEOM::mvtx_applymisalignment = Enable::MVTX_APPLYMISALIGNMENT;
  

  std::string geofile = CDBInterface::instance()->getUrl("Tracking_Geometry");
  Fun4AllRunNodeInputManager *ingeo = new Fun4AllRunNodeInputManager("GeoIn");
  ingeo->AddFile(geofile);
  se->registerInputManager(ingeo);

  G4TPC::ENABLE_MODULE_EDGE_CORRECTIONS = true;
  G4TPC::ENABLE_STATIC_CORRECTIONS = true;
  G4TPC::USE_PHI_AS_RAD_STATIC_CORRECTIONS=false;


  G4TPC::ENABLE_AVERAGE_CORRECTIONS = false;

  TRACKING::pp_mode = false;
  
  TrackingInit();


  G4TPC::LaminationOutputName = outfile; 
  G4TPC::LaminationQAName = QAfile;
  TPC_LaminationFitting();
  
  se->run(nEvents);
  se->End();
  CDBInterface::instance()->Print();
  se->PrintTimer();

  delete se;
  std::cout << "Finished" << std::endl;
  gSystem->Exit(0);
}
