using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class AccountBalance : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                ProcessRequest();
            }
        }

        public void ProcessRequest()
        {

            string url = "http://192.168.20.102:56088/api/Account/AccountBalance/CHENGWA";
            var request = (HttpWebRequest)WebRequest.Create(url);
            var response = (HttpWebResponse)request.GetResponse();
            string responseString;
            using (var stream = response.GetResponseStream())
            {
                using (var reader = new StreamReader(stream))
                {
                    responseString = reader.ReadToEnd();
                    JObject obj = JObject.Parse(responseString);
                    string accounts = obj["Responses"][0]["Model"]["Accounts"].ToString();
                    //Response.ContentType = "text/json";
                    //Response.Write(accounts);
                    txtResponse.Width = 800;
                    txtResponse.Height = 1600;
                    txtResponse.Text = accounts;
                }
            }

        }

        
    }
}