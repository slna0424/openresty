--作者：宫丹
--创建时间: 2016-12-02
--描述：公共方法

local cjson = require "cjson.safe";
local redis = require "resty.redis";
local http = require "resty.http"
local mysql = require("resty.mysql");

local redis_host = {REDIS_IP = "127.0.0.1", REDIS_PORT = 6379, REDIS_TIMEO = 30000, PASS = 62672000};
local mysql_host = {mysql_ip = "rm-2zez68k598ener9pti.mysql.rds.aliyuncs.com", mysql_port = "3306",mysql_database = "fnegou_db", mysql_user = "zichen", mysql_pwd = "Zxp62672000"};

local timeout = 30000;
local pool_max_idle_time = 20000; --毫秒  
local pool_size = 512; --连接池大小

local ok, new_tab = pcall(require, "table.new");
if not ok or type(new_tab) ~= "function" then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32);
_M._VERSION = "0.1";

--获取终端信息 
function _M.comm_function(request)

	local request_method = ngx.var.request_method;
	local http_body = nil;
	request.post_fields = {};
	if 	"POST" == request_method then
		ngx.req.read_body();
		http_body = ngx.req.get_body_data();
		if not http_body then
			local file_name = ngx.req.get_body_file();
			if not file_name then
				ngx.log(ngx.INFO, "no request body found");
				return false;
			else
				local fh, err = io.open(file_name, "r");
				if not fh then 
					ngx.log(ngx.INFO, "failed to open ", err);
					return false;
				else 
					fh:seek("set");
					http_body = fh:read("*a");
					fh:close();
					if http_body == "" then
						ngx.log(ngx.INFO, "request body is empty");
						return false;
					end
				end
			end
		end
	else
		ngx.log(ngx.INFO, "not handle request_method");
		return false;
	end

	ngx.log(ngx.INFO, "Request http_body: ", http_body);
	request.post_fields = cjson.decode(http_body);
	if not request.post_fields or request.post_fields == cjson.null then
		ngx.log(ngx.WARN, "cjson.decode empty, exit");
		return false;
	end
	return true;
end

--连接redis数据库
function _M.redis_connect(request)

	request.red, err = redis:new();
	if not request.red or err then
		ngx.log(ngx.ERR, "REDIS new read failed: ", err);
		return false;
	end
	request.red:set_timeout(redis_host.REDIS_TIMEO);
	local ok, err = request.red:connect(redis_host.REDIS_IP, redis_host.REDIS_PORT);
	if not ok or err then
		ngx.log(ngx.ERR, "REDIS read connect failed: ", err);
		return false;
	end
	
	local ok, err = request.red:auth(redis_host.PASS)
    if not ok or err then
        ngx.log(ngx.INFO,"failed to authenticate: ", err)
        return false;
    end
	
    return true;
end

--关闭数据库
function _M.redis_disconnect(request)
   	if not request.red then
	ngx.log(ngx.ERR,"request.red is null")
	return false;
    end
	--释放连接(连接池实现)  
	local ok, err = request.red:set_keepalive(pool_max_idle_time, pool_size); 
	if not ok then  
		ngx.log(ngx.ERR,"redis set keepalive error : ", err)  
	end 
	return true;
	
end

--发送、接收电商平台响应
function _M.send_or_rcv_msg(url, post_fields, response)
	response.msg = {};
	local str = cjson.encode(post_fields);
	local httpc = http.new()
	ngx.log(ngx.INFO,"send_msg: ",str);
	--timeout = timeout or 30000
	httpc:set_timeout(timeout)

	local res, err = httpc:request_uri(url, {
	 method = "POST",
	 body = str,
	 headers = {
		 ["Content-Type"] = "application/json",
	 }
	})
	--ngx.log(ngx.INFO, "err: ", err); 
	
	if not res then  
		ngx.log(ngx.WARN,"failed to request: ", err)  
		return false;  
	end  
	--请求之后，状态码  
	ngx.log(ngx.INFO, "res.status: ", res.status );
	ngx.status = res.status  
	if ngx.status ~= 200 then  
		ngx.log(ngx.WARN,"非200状态，ngx.status: ",ngx.status)  
		return false;  
	end  
	--响应的内容  
	ngx.log(ngx.INFO, "res.body: ",res.body);
	response.msg = cjson.decode(res.body);
	return true;
end

--链接mysql数据库
function _M.mysql_connect(request)
	request.db, err = mysql:new();
    if not request.db then
        ngx.log(ngx.ERR,"failed to instantiate mysql: ", err);
        return false;
    end
	ngx.log(ngx.INFO, "mysql_user: ",mysql_host.mysql_user," mysql_pwd: ",mysql_host.mysql_pwd);
	local ok, err, errcode, sqlstate = request.db:connect{
                    host = mysql_host.mysql_ip,
                    port = mysql_host.mysql_port,
                    database = mysql_host.mysql_database,
                    user = mysql_host.mysql_user,
                    password = mysql_host.mysql_pwd };

    if not ok then
        ngx.log(ngx.ERR,"failed to connect: ", err, ": ", errcode, " ", sqlstate);
        return false;
    end
	return true;
end

function _M.mysql_disconnect(request)
	if not request.db then
		ngx.log(ngx.ERR,"request.db is null")
        return false;
    end
	--释放连接(连接池实现)  
	local ok, err = request.db:set_keepalive(pool_max_idle_time, pool_size); 
	if not ok then  
		ngx.log(ngx.ERR,"mysql set keepalive error : ", err)  
	end 
	return true;
end

return _M;
















