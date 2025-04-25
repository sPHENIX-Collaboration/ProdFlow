#include <fun4all/Fun4AllServer.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllDstOutputManager.h>
#include <fun4allraw/SingleGl1TriggeredInput.h>
#include <fun4allraw/Fun4AllTriggeredInputManager.h>
#include <fun4allraw/InputManagerType.h>
#include <fun4all/Fun4AllOutputManager.h>

#include <ffamodules/FlagHandler.h>
#include <ffamodules/HeadReco.h>
#include <ffamodules/SyncReco.h>

#include <ffarawmodules/ClockDiffCheck.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libfun4allraw.so)
R__LOAD_LIBRARY(libffamodules.so)
R__LOAD_LIBRARY(libffarawmodules.so)

// The file lists are provided from the outside. gl1daq.list contains the gl1 files (needed
// for all jobs) and one or more sebXX.list files for the seb files. Currently just one seb per job

void Fun4All_New_Prdf_Combiner(int nEvents = 0,
			       std::string &outfile = "out.root",
			       std::string &outdir = "./")
{

  Fun4AllServer *se = Fun4AllServer::instance();
  se->Verbosity(1);
  se->VerbosityDownscale(1000);
  Fun4AllTriggeredInputManager *in = new Fun4AllTriggeredInputManager("Tin");
  SingleTriggeredInput *gl1 = new SingleGl1TriggeredInput("Gl1in");
  gl1->AddListFile("gl1daq.list");
//  gl1->Verbosity(10);
  in->registerGl1TriggeredInput(gl1);
  ifstream infile;
  SingleTriggeredInput *input = nullptr;
  for (int i=0; i<21; i++)
  {
    char daqhost[200];
    char daqlist[200];
    sprintf(daqhost,"seb%02d",i);
    sprintf(daqlist,"%s.list",daqhost);
    infile.open(daqlist);
    if (infile.is_open())
    {
      infile.close();
      input = new SingleTriggeredInput(daqhost);
      input->AddListFile(daqlist);
      in->registerTriggeredInput(input);
    }
  }
  se->registerInputManager(in);

  SyncReco *sync = new SyncReco();
  se->registerSubsystem(sync);

  HeadReco *head = new HeadReco();
  se->registerSubsystem(head);
  FlagHandler *flag = new FlagHandler();
  se->registerSubsystem(flag);

  ClockDiffCheck *clkchk = new ClockDiffCheck();
//   clkchk->Verbosity(3);
  clkchk->set_delBadPkts(true);
  se->registerSubsystem(clkchk);
  Fun4AllOutputManager *out = new Fun4AllDstOutputManager("dstout",outfile);
  out->UseFileRule();
  out->SetNEvents(100000); 
  out->SetClosingScript("stageout.sh");      // script to call on file close (not quite working yet...)
  out->SetClosingScriptArgs(outdir);  // additional beyond the name of the file
  se->registerOutputManager(out);
  if (nEvents >= 0)
  {
    se->run(nEvents);
  }
  se->End();
  delete se;
  std::cout << "all done" << std::endl;
  gSystem->Exit(0);
}
