/*
 * This macro is run in our daily CI and is intended as a minimum working
 * example showing how to unpack the raw hits into the offline tracker hit
 * format. No other reconstruction or analysis is performed
 */
#include <GlobalVariables.C>
#include <QA.C>
#include <Trkr_Clustering.C>
#include <Trkr_LaserClustering.C>
#include <Trkr_RecoInit.C>

#include <fun4all/Fun4AllDstInputManager.h>
#include <fun4all/Fun4AllDstOutputManager.h>
#include <fun4all/Fun4AllInputManager.h>
#include <fun4all/Fun4AllOutputManager.h>
#include <fun4all/Fun4AllRunNodeInputManager.h>
#include <fun4all/Fun4AllServer.h>
#include <fun4all/Fun4AllUtils.h>

#include <trackingqa/InttClusterQA.h>

#include "inttrawhitqa/InttRawHitQA.h"
#include <ffamodules/CDBInterface.h>
#include <ffamodules/FlagHandler.h>
#include <phool/recoConsts.h>

#include <stdio.h>

R__LOAD_LIBRARY(libfun4all.so)
R__LOAD_LIBRARY(libffamodules.so)
R__LOAD_LIBRARY(libintt.so)
R__LOAD_LIBRARY(libinttrawhitqa.so)
R__LOAD_LIBRARY(libtrackingqa.so)
void Fun4All_SingleJob0(const int nEvents = 2,                                    //
                        const int runnumber = 54280,                              //
                        const std::string outfilename = "inttcluster_ppg02.root", //
                        const std::string dbtag = "ProdA_2024",                   //
                        const std::string filelist = "filelist.list"              //
)
{
    bool saverawhit = true;

    gSystem->Load("libg4dst.so");

    auto se = Fun4AllServer::instance();
    se->Verbosity(1);
    auto rc = recoConsts::instance();

    std::ifstream ifs(filelist);
    std::string filepath;

    int i = 0;

    while (std::getline(ifs, filepath))
    {
        std::cout << "Adding DST with filepath: " << filepath << std::endl;
        if (i == 0)
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

    CDBInterface::instance()->Verbosity(1);

    rc->set_StringFlag("CDB_GLOBALTAG", dbtag);

    FlagHandler *flag = new FlagHandler();
    se->registerSubsystem(flag);

    std::string geofile = CDBInterface::instance()->getUrl("Tracking_Geometry");
    Fun4AllRunNodeInputManager *ingeo = new Fun4AllRunNodeInputManager("GeoIn");
    ingeo->AddFile(geofile);
    se->registerInputManager(ingeo);

    TrackingInit();

    for (int server = 0; server < 8; server++)
    {
        std::string str_server = std::to_string(server);
        auto inttunpacker = new InttCombinedRawDataDecoder("InttCombinedRawDataDecoder" + str_server);
        inttunpacker->Verbosity(std::max(Enable::VERBOSITY, Enable::INTT_VERBOSITY));
        inttunpacker->LoadHotChannelMapRemote("INTT_HotMap"); 
        inttunpacker->SetCalibBCO("INTT_BCOMAP", InttCombinedRawDataDecoder::CDB);
        inttunpacker->SetCalibDAC("INTT_DACMAP", InttCombinedRawDataDecoder::CDB);
        inttunpacker->runInttStandalone(true); // true for Au+Au; the time_bucket information will NOT be saved; false for p+p
        inttunpacker->writeInttEventHeader(true);
        inttunpacker->set_triggeredMode(true);
        inttunpacker->set_bcoFilter(true); // must be true when runInttStandalone is true; false for p+p
        if (str_server.length() > 0)
        {
            inttunpacker->useRawHitNodeName("INTTRAWHIT_" + str_server);
        }
        se->registerSubsystem(inttunpacker);
    }

    Intt_Clustering();

    // Fun4All standard QA
    se->registerSubsystem(new InttClusterQA);
    auto intt = new InttRawHitQA;
    se->registerSubsystem(intt);

    // nodes to save
    vector<std::string> nodes = {"Sync", "EventHeader", "GL1RAWHIT", "INTTEVENTHEADER", "TRKR_CLUSTER", "TRKR_HITSET", "TRKR_CLUSTERCROSSINGASSOC", "TRKR_CLUSTERHITASSOC"};
    Fun4AllOutputManager *out = new Fun4AllDstOutputManager("DSTOUT", outfilename);
    for (auto node : nodes)
    {
        out->AddNode(node);
    }
    if (saverawhit)
    {
        for (int server = 0; server < 8; server++)
        {
            std::string str_server = std::to_string(server);
            out->AddNode("INTTRAWHIT_" + str_server);
        }
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
