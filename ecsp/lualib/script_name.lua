--脚本名称




local ok, new_tab = pcall(require, "table.new");
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32);
_M._VERSION = "0.1";

_M.menu_script = "t_gmenu_0122.tcl";               --菜单
_M.prolist_script = "t_glist.tcl";            --商品列表
_M.login_script = "ec_login.tcl";             --登录
_M.logout_script = "ec_logout.tcl";           --登出
_M.proinfo_script = "ec_goods_details.tcl";   --商品详情
_M.cart_script = "shop_cart.tcl";             --查看购物车
_M.favorite_script = "t_favorite.tcl";        --查看收藏夹
_M.query_script = "t_query.tcl";              --订单查询
_M.order_script = "t_order.tcl";              --下单
_M.addcart_script = "t_addcart.tcl";          --加入购物车
_M.addfav_script = "t_addfavorite.tcl";       --加入收藏夹
_M.zmenu_script = "menu.tcl";                 --主界面
_M.payway_script = "t_payway.tcl";            --支付方式选择
_M.cardpay_script = "t_cardpay_0122.tcl";          --刷卡支付
_M.sjdpay_script = "t_sjdpay.tcl";            --双基贷
_M.ptdpay_script = "t_sjdpay.tcl"             --平台贷
_M.gclassfy_script = "t_gclassfy.tcl";        --分类
_M.gtitle_script = "t_gtitle.tcl";            --底部
_M.orderlist_script = "t_orderlist_0122.tcl";      --订单列表
_M.goodsinfo_script = "t_goodsinfo.tcl";

return _M;
 

