﻿<%@ Page Title="" Language="C#" EnableTheming="false" MasterPageFile="~/BPM.master"
    AutoEventWireup="true" CodeFile="DoneList.aspx.cs" Inherits="DoneList" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
    <script src="/js/My97DatePicker/WdatePicker.js" type="text/javascript"></script>
    <script src="/Resource/jquery/jquery-1.8.0.min.js" type="text/javascript">
    </script>
    <script src="/Resource/js/helper.js" type="text/javascript"></script>
    <div class="container">
        <div class="container">
            <div class="titlebg">
                <div class="title">
                    查询</div>
            </div>
            <div class="content">
                <table class="FormTable">
                    <tbody>
                        <tr>
                            <th>
                                标题：
                            </th>
                            <td>
                                <asp:TextBox ID="tbxTitle" runat="server" CssClass="txt" MaxLength="50" Width="150px"></asp:TextBox>
                            </td>
                            <th>
                                开始时间：
                            </th>
                            <td>
                                <input id="tbxBeginTime" runat="server" class="txt" style="width: 150px" onfocus="WdatePicker({isShowClear:true,readOnly:true,dateFmt:'yyyy-MM-dd'})" />
                                至
                                <input id="tbxEndTime" runat="server" class="txt" style="width: 150px" onfocus="WdatePicker({isShowClear:true,readOnly:true,dateFmt:'yyyy-MM-dd'})" />
                            </td>
                            <td>
                                <asp:Button ID="btnQuery" runat="server" CssClass="green_btn" Text="查询" OnClick="btnQuery_Click" />
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        <div class="titlebg">
            <div class="title">
                已办事项
            </div>
        </div>
        <div class="content">
            <asp:TextBox ID="tbUser" runat="server" Visible="false"></asp:TextBox>
            <asp:Button ID="btnSearch" runat="server" OnClick="btnSearch_Click" Text="切换用户" Visible="false" />
            <asp:GridView ID="gvDataList" runat="server" AutoGenerateColumns="False" CssClass="List"
                AllowPaging="True" OnPageIndexChanging="gvDataList_PageIndexChanging" PagerSettings-FirstPageText="首页"
                PagerSettings-Mode="NumericFirstLast" PagerSettings-LastPageText="尾页" PagerStyle-CssClass="anpager"
                PagerStyle-HorizontalAlign="Center">
                <Columns>
                    <asp:TemplateField HeaderText="查看">
                        <ItemTemplate>
                            <a onclick='ViewHistory("<%# Eval("flowFrom")%>","<%# Eval("InstanceID")%>","<%# Eval("VirtualPath")%>","<%# Eval("wfid")%>","<%# Eval("Step")%>")'
                                href='#'>
                                <img src="/Resource/images/dg_flow_l.gif" title="查看流转过程" /></a>
                        </ItemTemplate>
                        <ItemStyle HorizontalAlign="Center" Width="50px" />
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText="标题">
                        <ItemTemplate>
                            <a target="_blank" title="<%# Eval("FormTitle").ToString()%>" href='<%# GetApprovalPageUrl(Eval("flowFrom").ToString(),Eval("VirtualPath").ToString(),Eval("InstanceID").ToString(),Eval("taskid").ToString(),Eval("Step").ToString(),Eval("FormName").ToString())+"&u="+Eval("LoginId").ToString() %>'>
                                <%#Eval("FormTitle").ToString().Length > 30 ? Eval("FormTitle").ToString().Substring(0, 30) + "..." : Eval("FormTitle")%></a>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:BoundField HeaderText="发起人" DataField="CreateByUserName" ItemStyle-HorizontalAlign="Center"
                        ItemStyle-Width="50px" />
                    <asp:BoundField HeaderText="发起人部门" DataField="CreateDeptName" ItemStyle-Width="150px" />
                    <asp:BoundField HeaderText="待处理人" DataField="todoUser" ItemStyle-HorizontalAlign="Center"
                        ItemStyle-Width="55px" />
                    <%--              <asp:BoundField HeaderText="当前步骤"  DataField="Step"/>--%>
                    <asp:BoundField HeaderText="类型" DataField="AppName" ItemStyle-Width="100px" />
                    <asp:BoundField HeaderText="处理时间" DataField="ApproveAtTime" ItemStyle-Width="120px"
                        ItemStyle-HorizontalAlign="Left" />
                    <%--            <asp:BoundField HeaderText="状态" DataField="Status" />--%>
                    <asp:TemplateField HeaderText="源" ItemStyle-Width="25px" ItemStyle-HorizontalAlign="Left">
                        <ItemTemplate>
                            <%# Eval("flowFrom").ToString()=="0"?"OA":"BPM"%>
                        </ItemTemplate>
                    </asp:TemplateField>
                    <asp:TemplateField HeaderText=" " ItemStyle-Width="25px" ItemStyle-HorizontalAlign="Left">
                        <ItemTemplate>
                            <div style='<%# Eval("flowFrom").ToString()=="0"||!Reminder.IsShow(Eval("InstanceID").ToString())?"display:none;": ""%>'>
                                <input style="border-style: none; text-decoration: none;color: #005ea7; cursor:pointer; background-color:transparent;" type="button" value="催办" onclick='javascript:$.get(&#39;RemindHander.ashx?flowid=<%# Eval("InstanceID") %>&#39;, function(data){alert(data);});' />
                            </div>
<%--                            <a  id='rh_<%#Eval("InstanceID").ToString()%>'  href='#rh_<%#Eval("InstanceID").ToString()%>' onclick='javascript:$.get(&#39;RemindHander.ashx?flowid=<%# Eval("InstanceID") %>&#39;, function(data){alert(data);});'>催办</a>
--%>                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>
        </div>
    </div>
    <script type="text/javascript">
        function ViewHistory(type, caseID, virtualpath, wfid, status) {
            if (status == "拟稿") {
                alert("没有流转情况");
                return;
            }
            var sFeatures = "dialogHeight:450px; dialogWidth:600px; dialogTop: px; dialogLeft: px; edge:Raised; center: Yes; help: Yes; status:Yes;scroll:auto;resizable: Yes";
            var keys = caseID;
            var url = "";
            if (type == 0) {
                url = "http://oa.founder.com/" + virtualpath + 'Modules/Workflow/ViewHistory.aspx?keys=' + keys;
            }
            else {
                sFeatures = "dialogHeight:450px; dialogWidth:700px; dialogTop: px; dialogLeft: px; edge:Raised; center: Yes; help: Yes; status:Yes;scroll:auto;resizable: Yes";
                //url = "http://zy-bpmtest:81/ViewFlow/ViewFlow.aspx?ViewTypeName=ProcessView&K2Server=ZY-BPMTEST:5252&HostServerName=ZY-BPMTEST&HostServerPort=5555&ProcessID=" + wfid;
                url = "ProcessHistory.aspx?CaseID=" + caseID;

            }
            window.showModalDialog(url, '1', sFeatures);
        }
    </script>
</asp:Content>
