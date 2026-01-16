using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class ManageMonitorStock : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                GetMonitorStockList();
            }
        }
        private void GetMonitorStockList()
        {
            DataTable dtMonitorStock;
            DataOperation doMonitorStock = new DataOperation();
            dtMonitorStock = doMonitorStock.GetMonitorStock().Tables[0];
            DataListMonitorStock.DataSource = dtMonitorStock;
            DataListMonitorStock.DataBind();
            
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            string message = "";
            if(txtStockCode.Text.Length > 0)
            {
                DataOperation doAdd = new DataOperation();
                message = doAdd.AddMonitorStock(txtStockCode.Text);
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetMonitorStockList();
            }

        }
        void Clear()
        {
            txtStockCode.Text = String.Empty;
        }

        protected void DataListMonitorStock_DeleteCommand(object source, DataListCommandEventArgs e)
        {
            string stockCode = DataListMonitorStock.DataKeys[e.Item.ItemIndex].ToString();

            if (stockCode.Length > 0)
            {
                DataOperation doDelete = new DataOperation();
                doDelete.DeleteMonitorStock(stockCode);
                //Clear();
                Response.Write("<script type=\"text/javascript\">alert('Record Deleted Successfully');</script>");
                GetMonitorStockList();
            }
            
        }
        protected void DataListMonitorStock_EditCommand(object source, DataListCommandEventArgs e)
        {
            DataListMonitorStock.EditItemIndex = e.Item.ItemIndex;
            GetMonitorStockList();
        }
        protected void DataListMonitorStock_CancelCommand(object source, DataListCommandEventArgs e)
        {
            DataListMonitorStock.EditItemIndex = -1;
            GetMonitorStockList();
        }
        protected void DataListMonitorStock_UpdateCommand(object source, DataListCommandEventArgs e)
        {
            string stockCode = DataListMonitorStock.DataKeys[e.Item.ItemIndex].ToString();
            TextBox txtUpdate = (TextBox)e.Item.FindControl("txtUpdateStockCode");
            TextBox txtUpdatePriorityLevel = (TextBox)e.Item.FindControl("txtUpdatePriorityLevel");
            TextBox txtUpdateNotes = (TextBox)e.Item.FindControl("txtUpdateNotes");
            string stockCodeNew = txtUpdate.Text;
            int priorityLevel = Convert.ToInt16(txtUpdatePriorityLevel.Text);
            string notes = txtUpdateNotes.Text;
            string message = "";

            if (stockCode.Length > 0 && stockCodeNew.Length > 0)
            {
                DataOperation doUpdate = new DataOperation();
                message = doUpdate.UpdateMonitorStock(stockCode, stockCodeNew, priorityLevel, notes);
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetMonitorStockList();
            }
        }
    }
}