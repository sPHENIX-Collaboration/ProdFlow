#ifndef FUN4ALL_YEAR2_FITTING_C
#define FUN4ALL_YEAR2_FITTING_C

#include <QA.C>
#include <Calo_Fitting.C>

#include <ffamodules/CDBInterface.h>
#include <ffamodules/FlagHandler.h>
#include <ffamodules/HeadReco.h>
#include <ffamodules/SyncReco.h>

#include <fun4all/Fun4AllDstInputManager.h>
#include <fun4all/Fun4AllDstOutputManager.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllRunNodeInputManager.h>
#include <fun4all/Fun4AllServer.h>
#include <fun4all/Fun4AllUtils.h>
#include <fun4all/SubsysReco.h>
#include <calotrigger/TriggerRunInfoReco.h>

#include <phool/recoConsts.h>

#include <calovalid/CaloFittingQA.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libfun4allraw.so)
R__LOAD_LIBRARY(libcalovalid.so)
R__LOAD_LIBRARY(libcalotrigger.so)
  
// this pass containis the reco process that's stable wrt time stamps(raw tower building)
void Fun4All_Year2_Fitting(int nEvents = 100,
			   const std::string &fname = "DST_TRIGGERED_EVENT_run2pp_new_2024p003-00048185-0000.root",
                   const std::string &outfile = "DST_CALOFITTING-00000000-000000.root",
                   const std::string& outfile_hist= "HIST_CALOFITTINGQA-00000000-000000.root",
                   const std::string &dbtag = "ProdA_2024")
{
  Fun4AllServer *se = Fun4AllServer::instance();
  se->Verbosity(0);

  recoConsts *rc = recoConsts::instance();

  pair<int, int> runseg = Fun4AllUtils::GetRunSegment(fname);
  int runnumber = runseg.first;

  // conditions DB flags and timestamp
  rc->set_StringFlag("CDB_GLOBALTAG", dbtag);
  rc->set_uint64Flag("TIMESTAMP", runnumber);
  CDBInterface::instance()->Verbosity(1);

  FlagHandler *flag = new FlagHandler();
  se->registerSubsystem(flag);

  // Get info from DB and store in DSTs
  TriggerRunInfoReco *triggerinfo = new TriggerRunInfoReco();
  se->registerSubsystem(triggerinfo);

  Process_Calo_Fitting();

  ///////////////////////////////////
  // Validation 
  CaloFittingQA *ca = new CaloFittingQA("CaloFittingQA");
  //ca->set_debug(false);
  se->registerSubsystem(ca);

  Fun4AllInputManager *In = new Fun4AllDstInputManager("in");
  In->AddFile(fname);
  se->registerInputManager(In);

  Fun4AllDstOutputManager *out = new Fun4AllDstOutputManager("DSTOUT", outfile);
  out->StripNode("CEMCPackets");
  out->StripNode("HCALPackets");
  out->StripNode("ZDCPackets");
  out->StripNode("SEPDPackets");
  se->registerOutputManager(out);

  se->run(nEvents);
  se->End();

  QAHistManagerDef::saveQARootFile(outfile_hist);

  CDBInterface::instance()->Print();  // print used DB files
  se->PrintTimer();
  delete se;
  std::cout << "All done!" << std::endl;
  gSystem->Exit(0);
}
#endif
