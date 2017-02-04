--下载脚本
local ok, new_tab = pcall(require, "table.new");
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32);
_M._VERSION = "0.1";

_M.script_path = "/home/zichen/ecs/trans/";
_M.pic_path = "/home/zichen/ecs/img/";
_M.local_pic_path = "/home/zichen/ecs/img/pic/";
_M.web_pic_path = "/usr/local/tomcat/tomcat-7.0/webapps/ejsimage";
_M.file_path = "/home/zichen/ecs/tcl_array/tcl_file/";
_M.pro_list_url = "http://59.110.112.70:8888/front/product/select";
_M.pro_info_url = "http://59.110.112.70:8888/front/prt_goods/select";
_M.pro_order_url = "http://59.110.112.70:8888/admin/order/add";
_M.gmenu_url = "http://59.110.112.70:8888/front/cate/select";
_M.pro_payways_url = "http://59.110.112.70:8888/admin/order/pay/select";
_M.pro_paystate_url = "http://59.110.112.70:8888/admin/order/pay/state";
_M.order_state_url = "http://59.110.112.70:8888/admin/orderstate/sel";
_M.order_list_url = "http://59.110.112.70:8888/admin/order/sel";

return _M;

