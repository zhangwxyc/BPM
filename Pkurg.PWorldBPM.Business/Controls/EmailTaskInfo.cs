﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Pkurg.PWorldBPM.Business.Controls
{
    public class EmailTaskInfo
    {
        public string InstanceID { get; set; }
        public string Sn { get; set; }
        public string CreateDeptName { get; set; }
        public string CreateByUserName { get; set; }
        public DateTime SumitTime { get; set; }
        public string AppName { get; set; }
        public string Email { get; set; }
    }
}
