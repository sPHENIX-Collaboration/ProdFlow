#include <fstream>
void drawProdTrackingQA(int runlo, int runhi, string prodtag, string buildtag)
{
  gStyle->SetOptTitle(0);
  gStyle->SetOptStat(0);

  int run;
  int ntrigger;
  int ncalofitting;
  int ncalo;
  
  int nlowrun = runlo;
  int nhighrun = runhi;
  int binrun = nhighrun - nlowrun + 1;
  float lowrun = nlowrun - 0.5; 
  float highrun = nhighrun + 0.5;
  const int querytype = 5;
  TH1D* h1_dsttype[querytype];

  for(int i=0; i<querytype; ++i)
    {
      h1_dsttype[i] = new TH1D(("h1_tracking_"+to_string(i)).c_str(),"",binrun,lowrun,highrun);
    }
  TSQLServer *db = TSQLServer::Connect("pgsql://sphnxdbmaster:5432/FileCatalog","","");
  if (db)
    {
      printf("Server info: %s\n", db->ServerInfo());
    }
  else
    {
      printf("bad\n");
      exit(1);
    }

  TSQLRow *row;
  TSQLResult *res;
  char sql[querytype][1000];
  int nseg[querytype];
  
  string dsttype[querytype] = {"DST_STREAMING_EVENT","DST_TRKR_HIT","DST_TRKR_CLUSTER","DST_TRKR_SEED","DST_TRKR_TRACKS"};

  for(int i=1; i<querytype; ++i)
    {
      sprintf(sql[i], "WITH ranked_datasets AS (SELECT runnumber, segment, dsttype, filename FROM datasets WHERE dsttype = '%s_run2pp' AND filename LIKE '%%%s%%%s%%' AND runnumber BETWEEN %d AND %d) SELECT runnumber, COUNT(DISTINCT segment) AS segment_count FROM ranked_datasets GROUP BY runnumber;", dsttype[i].c_str(), buildtag.c_str(), prodtag.c_str(), runlo, runhi);
    }

  sprintf(sql[0], "WITH ranked_datasets AS (SELECT runnumber, segment, dsttype, filename FROM datasets WHERE dsttype = '%s_run2pp' AND filename LIKE '%%%s%%%s%%' AND runnumber BETWEEN %d AND %d) SELECT runnumber, COUNT(DISTINCT segment) AS segment_count FROM ranked_datasets GROUP BY runnumber;", dsttype[0].c_str(), buildtag.c_str(), "2024p002", runlo, runhi);

  for(int h=0; h<querytype; ++h)
    {
      cout << sql[h] << endl;
      res = db->Query(sql[h]);      
      
      int nrows = res->GetRowCount();
      for (int i = 0; i < nrows; i++)
        {
          row = res->Next();
	  if(h==2 && stof(row->GetField(0)) != 0) cout << stof(row->GetField(0)) << " " << stof(row->GetField(1)) << endl;
	  h1_dsttype[h]->Fill(stof(row->GetField(0)),stof(row->GetField(1)));
          delete row;
        }
    }
  delete res;
  delete db;

  TCanvas *c = new TCanvas("c","c", 1000, 500);
  h1_dsttype[0]->SetFillColor(2);
  h1_dsttype[0]->SetLineColor(2);
  h1_dsttype[0]->Draw("hist");
  for(int i=1; i<querytype; ++i)
    {
      h1_dsttype[i]->SetFillColor(i+2);
      h1_dsttype[i]->SetLineColor(i+2);
      h1_dsttype[i]->Draw("hist same");
    }

  c->Print("prod_qa_tracking_jocl.pdf");
}
