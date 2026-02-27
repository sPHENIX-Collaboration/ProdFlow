#include <fstream>
void drawProdQA(int runlo, int runhi, string prodtag, string buildtag)
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
  const int querytype = 3;
  TH1D* h1_dsttype[querytype];
  h1_dsttype[0] = new TH1D("h_trigger","", binrun, lowrun, highrun); 
  h1_dsttype[1] = new TH1D("h_calofitting","", binrun, lowrun, highrun); 
  h1_dsttype[2] = new TH1D("h_calo","", binrun, lowrun, highrun); 
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

  sprintf(sql[2], "WITH ranked_datasets AS (SELECT runnumber, segment, dsttype, filename FROM datasets WHERE dsttype = 'DST_CALO_run2pp' AND filename LIKE '%%%s%%%s%%' AND runnumber BETWEEN %d AND %d) SELECT runnumber, COUNT(DISTINCT segment) AS segment_count FROM ranked_datasets GROUP BY runnumber;", buildtag.c_str(), prodtag.c_str(), runlo, runhi);

  sprintf(sql[1], "WITH ranked_datasets AS (SELECT runnumber, segment, dsttype, filename FROM datasets WHERE dsttype = 'DST_CALOFITTING_run2pp' AND filename LIKE '%%%s%%%s%%' AND runnumber BETWEEN %d AND %d) SELECT runnumber, COUNT(DISTINCT segment) AS segment_count FROM ranked_datasets GROUP BY runnumber;", buildtag.c_str(), prodtag.c_str(), runlo, runhi);

  sprintf(sql[0], "WITH ranked_datasets AS (SELECT runnumber, segment, dsttype, filename FROM datasets WHERE dsttype = 'DST_TRIGGERED_EVENT_run2pp' AND filename LIKE '%%%s%%%s%%' AND runnumber BETWEEN %d AND %d) SELECT runnumber, COUNT(DISTINCT segment) AS segment_count FROM ranked_datasets GROUP BY runnumber;", buildtag.c_str(), prodtag.c_str(), runlo, runhi);

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
  h1_dsttype[0]->SetFillColor(kBlue);
  h1_dsttype[0]->SetLineColor(kBlue);
  h1_dsttype[2]->SetFillColor(kRed);
  h1_dsttype[2]->SetLineColor(kRed);
  h1_dsttype[1]->SetFillColor(kSpring+2);
  h1_dsttype[1]->SetLineColor(kSpring+2);
  h1_dsttype[0]->Draw("hist");
  h1_dsttype[1]->Draw("hist same");
  h1_dsttype[2]->Draw("hist same");

  c->Print("prod_qa_jocl.pdf");
}
