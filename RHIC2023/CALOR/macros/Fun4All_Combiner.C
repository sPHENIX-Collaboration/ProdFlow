#include <fun4all/Fun4AllServer.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4allraw/SinglePrdfInput.h>
#include <fun4allraw/Fun4AllPrdfInputManager.h>
#include <fun4allraw/Fun4AllPrdfInputPoolManager.h>
#include <fun4all/Fun4AllOutputManager.h>

#include <fun4allraw/Fun4AllEventOutputManager.h>

//#include <ffarawmodules/EventCombiner.h>
//#include <ffarawmodules/EventNumberCheck.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libfun4allraw.so)
R__LOAD_LIBRARY(libffarawmodules.so)

void Fun4All_Combiner(int nEvents = 0,
		      const string &input_file00 = "seb00.list",
		      const string &input_file01 = "seb01.list",
		      const string &input_file02 = "seb02.list",
		      const string &input_file03 = "seb03.list",
		      const string &input_file04 = "seb04.list",
		      const string &input_file05 = "seb05.list",
		      const string &input_file06 = "seb06.list",
		      const string &input_file07 = "seb07.list",
		      const string &input_file08 = "hcalwest.list",
		      const string &input_file09 = "hcaleast.list",
		      const string &input_file10 = "zdc.list",
		      const string &input_file11 = "mbd.list",
		      const string &outputDir = "." )
{
  vector<string> infile_tmp;
  vector<string> infile;
  infile_tmp.push_back(input_file00);
  infile_tmp.push_back(input_file01);
  infile_tmp.push_back(input_file02);
  infile_tmp.push_back(input_file03);
  infile_tmp.push_back(input_file04);
  infile_tmp.push_back(input_file05);
  infile_tmp.push_back(input_file06);
  infile_tmp.push_back(input_file07);
  infile_tmp.push_back(input_file08);
  infile_tmp.push_back(input_file09);
  infile_tmp.push_back(input_file10);
  infile_tmp.push_back(input_file11);
  for (int i=0; i<infile_tmp.size(); i++)
  {
// C++ std17 filesystem::exists does not work in our CLING version
    ifstream in(infile_tmp[i]);
    if (in.is_open()) // does it exist?
    {
      if (in.peek() != std::ifstream::traits_type::eof()) // is it non zero?
      {
       infile.push_back(infile_tmp[i]);
      }
      in.close();
    }
  }
  Fun4AllServer *se = Fun4AllServer::instance();
  Fun4AllPrdfInputPoolManager *in = new Fun4AllPrdfInputPoolManager("Comb");
  //in->Verbosity(10);
  for (auto iter : infile)
  {
    if (iter.find("mbd") != string::npos) // the mbd is the reference
    {
      in->AddPrdfInputList(iter)->MakeReference(true);
    }
    in->AddPrdfInputList(iter);
  }

  se->registerInputManager(in);
  gSystem->Exit(0);

//  EventNumberCheck *evtchk = new EventNumberCheck();
//  evtchk->MyPrdfNode("PRDF");
//  se->registerSubsystem(evtchk);

//  Fun4AllEventOutputManager *out = new Fun4AllEventOutputManager("EvtOut","/sphenix/lustre01/sphnxpro/commissioning/aligned/beam-%08d-%04d.prdf",20000);
  //Fun4AllEventOutputManager *out = new Fun4AllEventOutputManager("EvtOut","./beam_emcal-%08d-%04d.prdf",nGB*1000.0);
    Fun4AllEventOutputManager *out = new Fun4AllEventOutputManager("EvtOut", outputDir+"/"+"beam_emcal-%08d-%04d.prdf",20000);
    out->DropPacket(21102);
  se->registerOutputManager(out);

  if (nEvents < 0) { return; }

  se->run(nEvents);

  se->End();
  delete se;
  gSystem->Exit(0);
}
