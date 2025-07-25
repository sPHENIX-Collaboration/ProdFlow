/*
 * This macro is run in our daily CI and is intended as a minimum working
 * example showing how to unpack the raw hits into the offline tracker hit
 * format. No other reconstruction or analysis is performed
 */
#include <GlobalVariables.C>
#include <Trkr_Clustering.C>
#include <Trkr_RecoInit.C>
#include <Trkr_Reco.C>
#include <Trkr_TpcReadoutInit.C>
#include <QA.C>

#include <fun4all/Fun4AllUtils.h>
#include <fun4all/Fun4AllDstInputManager.h>
#include <fun4all/Fun4AllDstOutputManager.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllOutputManager.h>
#include <fun4all/Fun4AllRunNodeInputManager.h>
#include <fun4all/Fun4AllServer.h>

#include <ffamodules/CDBInterface.h>
#include <ffamodules/FlagHandler.h>

#include <trackingqa/TrackFittingQA.h>
#include <trackingqa/TpcSiliconQA.h>
#include <trackingqa/VertexQA.h>

#include <phool/recoConsts.h>

#include <stdio.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libffamodules.so)
R__LOAD_LIBRARY(libmvtx.so)
R__LOAD_LIBRARY(libintt.so)
R__LOAD_LIBRARY(libtpc.so)
R__LOAD_LIBRARY(libmicromegas.so)
R__LOAD_LIBRARY(libtrack_reco.so)
R__LOAD_LIBRARY(libtrackingqa.so)
void Fun4All_JobC(
    const int nEvents = 2,
    const int runnumber = 41626,
    const std::string outfilename = "cosmictrack",
    const std::string dbtag = "2024p001",
    const std::string filelist = "filelist.list")
{
  gSystem->Load("libg4dst.so");

  ACTSGEOM::mvtx_applymisalignment = true;
  Enable::MVTX_APPLYMISALIGNMENT = true;
  
  auto se = Fun4AllServer::instance();
  se->Verbosity(1);
  auto rc = recoConsts::instance();
  CDBInterface::instance()->Verbosity(1);

  rc->set_StringFlag("CDB_GLOBALTAG", dbtag );
  
  FlagHandler *flag = new FlagHandler();
  se->registerSubsystem(flag);
  
  std::ifstream ifs(filelist);
  std::string filepath;
  int i = 0;
  while(std::getline(ifs,filepath))
    {
      if(i==0)
	{
	   std::pair<int, int> runseg = Fun4AllUtils::GetRunSegment(filepath);
	   int runNumber = runseg.first;
	   int segment = runseg.second;
	   rc->set_IntFlag("RUNNUMBER", runNumber);
	   rc->set_uint64Flag("TIMESTAMP", runNumber);
	}
      std::string inputname = "InputManager" + std::to_string(i);
      auto hitsin = new Fun4AllDstInputManager(inputname);
      hitsin->fileopen(filepath);
      se->registerInputManager(hitsin);
      i++;
    }

  TpcReadoutInit( runnumber );
  std::cout<< " run: " << runnumber
	   << " samples: " << TRACKING::reco_tpc_maxtime_sample
	   << " pre: " << TRACKING::reco_tpc_time_presample
	   << " vdrift: " << G4TPC::tpc_drift_velocity_reco
	   << std::endl;
  
  G4TPC::ENABLE_MODULE_EDGE_CORRECTIONS = true;

  // to turn on the default static corrections, enable the two lines below
  G4TPC::ENABLE_STATIC_CORRECTIONS = true;
  G4TPC::USE_PHI_AS_RAD_STATIC_CORRECTIONS = false;

  //to turn on the average corrections, enable the three lines below
  //note: these are designed to be used only if static corrections are also applied
  G4TPC::ENABLE_AVERAGE_CORRECTIONS = true;
  G4TPC::USE_PHI_AS_RAD_AVERAGE_CORRECTIONS = false;
  G4TPC::average_correction_filename = CDBInterface::instance()->getUrl("TPC_LAMINATION_FIT_CORRECTION");
  
  std::string geofile = CDBInterface::instance()->getUrl("Tracking_Geometry");
  Fun4AllRunNodeInputManager *ingeo = new Fun4AllRunNodeInputManager("GeoIn");
  ingeo->AddFile(geofile);
  se->registerInputManager(ingeo);

  /*
   * flags for tracking
   */
  G4TPC::REJECT_LASER_EVENTS=true;
  TRACKING::pp_mode = true;
  TrackingInit();

  // reject laser events if G4TPC::REJECT_LASER_EVENTS is true 
  Reject_Laser_Events();

  

  /*
   * Track Matching between silicon and TPC
   */
  // The normal silicon association methods
  // Match the TPC track stubs from the CA seeder to silicon track stubs from PHSiliconTruthTrackSeeding
  auto silicon_match = new PHSiliconTpcTrackMatching;
  silicon_match->Verbosity(0);
  silicon_match->set_pp_mode(TRACKING::pp_mode);
  if(G4TPC::ENABLE_AVERAGE_CORRECTIONS)
    {
      // for general tracking
      // Eta/Phi window is determined by 3 sigma window
      // X/Y/Z window is determined by 4 sigma window
      silicon_match->window_deta.set_posQoverpT_maxabs({-0.014,0.0331,0.48});
      silicon_match->window_deta.set_negQoverpT_maxabs({-0.006,0.0235,0.52});
      silicon_match->set_deltaeta_min(0.03);
      silicon_match->window_dphi.set_QoverpT_range({-0.15,0,0}, {0.15,0,0});
      silicon_match->window_dx.set_QoverpT_maxabs({3.0,0,0});
      silicon_match->window_dy.set_QoverpT_maxabs({3.0,0,0});
      silicon_match->window_dz.set_posQoverpT_maxabs({1.138,0.3919,0.84});
      silicon_match->window_dz.set_negQoverpT_maxabs({0.719,0.6485,0.65});
      silicon_match->set_crossing_deltaz_max(30);
      silicon_match->set_crossing_deltaz_min(2);
      
      // for distortion correction using SI-TPOT fit and track pT>0.5
      if (G4TRACKING::SC_CALIBMODE)
	{
	  silicon_match->window_deta.set_posQoverpT_maxabs({0.016,0.0060,1.13});
	  silicon_match->window_deta.set_negQoverpT_maxabs({0.022,0.0022,1.44});
	  silicon_match->set_deltaeta_min(0.03);
	  silicon_match->window_dphi.set_QoverpT_range({-0.15,0,0}, {0.09,0,0});
	  silicon_match->window_dx.set_QoverpT_maxabs({2.0,0,0});
	  silicon_match->window_dy.set_QoverpT_maxabs({1.5,0,0});
	  silicon_match->window_dz.set_posQoverpT_maxabs({1.213,0.0211,2.09});
	  silicon_match->window_dz.set_negQoverpT_maxabs({1.307,0.0001,4.52});
	  silicon_match->set_crossing_deltaz_min(1.2);
	}
    }
  se->registerSubsystem(silicon_match);

  // Match TPC track stubs from CA seeder to clusters in the micromegas layers
  auto mm_match = new PHMicromegasTpcTrackMatching;
  mm_match->Verbosity(0);
  mm_match->set_rphi_search_window_lyr1(3.);
  mm_match->set_rphi_search_window_lyr2(15.0);
  mm_match->set_z_search_window_lyr1(30.0);
  mm_match->set_z_search_window_lyr2(3.);

  mm_match->set_min_tpc_layer(38);             // layer in TPC to start projection fit
  mm_match->set_test_windows_printout(false);  // used for tuning search windows only
  se->registerSubsystem(mm_match);

  
  auto deltazcorr = new PHTpcDeltaZCorrection;
  deltazcorr->Verbosity(0);
  se->registerSubsystem(deltazcorr);
  
  // perform final track fit with ACTS
  auto actsFit = new PHActsTrkFitter;
  actsFit->Verbosity(0);
  actsFit->commissioning(G4TRACKING::use_alignment);
  // in calibration mode, fit only Silicons and Micromegas hits
  actsFit->fitSiliconMMs(G4TRACKING::SC_CALIBMODE);
  actsFit->setUseMicromegas(G4TRACKING::SC_USE_MICROMEGAS);
  actsFit->set_pp_mode(TRACKING::pp_mode);
  actsFit->set_use_clustermover(true);  // default is true for now
  actsFit->useActsEvaluator(false);
  actsFit->useOutlierFinder(false);
  actsFit->setFieldMap(G4MAGNET::magfield_tracking);
  se->registerSubsystem(actsFit);
  
  
  auto cleaner = new PHTrackCleaner();
  cleaner->Verbosity(0);
  cleaner->set_pp_mode(TRACKING::pp_mode);
  se->registerSubsystem(cleaner);

  PHSimpleVertexFinder *finder = new PHSimpleVertexFinder;
  finder->Verbosity(0);
  finder->setDcaCut(0.05);
  finder->setTrackPtCut(0.1);
  finder->setBeamLineCut(1);
  finder->setTrackQualityCut(300);
  finder->setNmvtxRequired(3);
  finder->setOutlierPairCut(0.1);
  se->registerSubsystem(finder);

  auto vtxProp = new PHActsVertexPropagator;
  vtxProp->Verbosity(0);
  vtxProp->fieldMap(G4MAGNET::magfield_tracking);
  se->registerSubsystem(vtxProp);
  
  
  auto tpcsiliconqa = new TpcSiliconQA;
  se->registerSubsystem(tpcsiliconqa);

  se->registerSubsystem(new TrackFittingQA);
  se->registerSubsystem(new VertexQA);
  
  Fun4AllOutputManager *out = new Fun4AllDstOutputManager("DSTOUT", outfilename);
  out->AddNode("Sync");
  out->AddNode("EventHeader");
  out->AddNode("GL1RAWHIT");
  out->AddNode("SvtxTrackSeedContainer");
  out->AddNode("SvtxTrackMap");
  out->AddNode("SvtxVertexMap");
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
