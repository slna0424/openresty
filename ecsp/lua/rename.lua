--作者：宫丹
--创建时间: 2016-12-13
--描述：文件重命名

local cjson = require("cjson.safe");
local path = require("path");
local common = require ("comm");
local pool_mysql = common.mysql_connect;
local close_mysql = common.mysql_disconnect;


--查询数据库
local function select_mysql_info(request)

	local file_name = "";
--	local middle = "middle";
	--商品spu、分类id
	local sql =  "SELECT id,name FROM product_cate WHERE path='/' and status <> 4 and status <> 3";
--	db:query("SET NAMES UTF8")
	
	local res, err, errcode, sqlstate = request.db:query(sql)
	if not res then
		ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
		return false;
	end
	ngx.log(ngx.INFO, "#res: ", #res);

	for i = 1, #res do
		ngx.log(ngx.INFO, "id: ", res[i].id);
		file_name = string.format("%s%s", path.pic_path, res[i].id);
		ngx.log(ngx.INFO, "file_name: ", file_name);
		local file,err=io.open(file_name)
		ngx.log(ngx.INFO, "file: ", type(file));
		if file == nil then
			local cmd = string.format("mkdir %s", file_name);
			os.execute(cmd);
		end		
		local sql5 = string.format("SELECT p.id as id,p.product_code as product_code FROM product_cate pc INNER JOIN (SELECT id FROM product_cate WHERE pid= '%s') tt on pc.pid=tt.id INNER JOIN product p ON p.product_cate_id=pc.id WHERE p.state=6", res[i].id);
		
		local res5, err, errcode, sqlstate = request.db:query(sql5)
		if not res5 then
			ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
			return false;
		end
		ngx.log(ngx.INFO, "#res5: ", #res5);
		for k = 1, #res5 do
			if string.len(res5[k].product_code) ~= 0 then
				--商品图片
				local sql1 = string.format("select CONCAT(SUBSTRING_INDEX(image_path,'/',4),'/middle/',SUBSTRING_INDEX(image_path,'/',-1)) as image_path,product_lead from product_picture where product_id='%s'", res5[k].id);
				local res1, err, errcode, sqlstate = request.db:query(sql1)
				if not res1 then
					ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
					return false;
				end
				ngx.log(ngx.INFO, "#res1: ", #res1);
				
				for j = 1, #res1 do		
				--	if res1[j].product_lead == "1" then
					
				--	end
					local pic_name = res5[k].product_code .. "_" .. j;
					ngx.log(ngx.INFO, "pic_name: ", pic_name);
					local cmd1 = string.format("cp %s%s %s/%s.png", path.web_pic_path, res1[j].image_path,file_name, pic_name);
					ngx.log(ngx.INFO, "cmd1: ", cmd1);
					os.execute(cmd1);
				end	
				--货品sku
				local sql2 = string.format("select id,norm_attr_id,sku, mall_casm_price from product_goods WHERE product_id= '%s' and state=1", res5[k].id);
				local res2, err, errcode, sqlstate = request.db:query(sql2)
				if not res2 then
					ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
					return false;
				end
				ngx.log(ngx.INFO, "#res2: ", #res2);
						
				for m = 1, #res2 do	
					ngx.log(ngx.INFO, "norm_attr_id: ", res2[m].norm_attr_id);
					local sql3 = string.format("select image from product_norm_attr_opt where attr_id IN ('%s') and product_id='%s' and image is not null",res2[m].norm_attr_id, res5[k].id);
					ngx.log(ngx.INFO, "sql3: ", sql3);
					local res3, err, errcode, sqlstate = request.db:query(sql3)
					if not res3 then
						ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
						return false;
					end
					ngx.log(ngx.INFO, "#res3: ", #res3);
					if #res3 == 0 then
						local sql4 = string.format("select CONCAT(SUBSTRING_INDEX(p.image_path,'/',4),'/middle/',SUBSTRING_INDEX(p.image_path,'/',-1)) as image_path from product_goods g inner join product_picture p on g.product_id=p.product_id where p.product_lead=1 and g.sku='%s'", res2[m].sku);
						ngx.log(ngx.INFO, "sql4: ", sql4);
						local res4, err, errcode, sqlstate = request.db:query(sql4)
						if not res4 then
							ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
							return false;
						end
						ngx.log(ngx.INFO, "#res4: ", #res4);
						cmd2 = string.format("cp %s%s %s/%s.png", path.web_pic_path, res4[1].image_path,file_name, res2[m].sku);
						os.execute(cmd2);
					else
						for n = 1, #res3 do
							if res3[n].image ~= ngx.null then
								cmd2 = string.format("cp %s%s %s/%s.png", path.web_pic_path,res3[n].image, file_name, res2[m].sku);
							else 
								local sql4 = string.format("select CONCAT(SUBSTRING_INDEX(p.image_path,'/',4),'/middle/',SUBSTRING_INDEX(p.image_path,'/',-1)) as image_path from product_goods g inner join product_picture p on g.product_id=p.product_id where p.product_lead=1 and g.sku='%s'", res2[m].sku);
								local res4, err, errcode, sqlstate = request.db:query(sql4)
								if not res4 then
									ngx.log(ngx.ERR," bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
									return false;
								end
								ngx.log(ngx.INFO, "#res4: ", #res4);
								cmd2 = string.format("cp %s%s %s/%s.png", path.web_pic_path, res4[1].image_path,file_name, res2[m].sku);
							end
							ngx.log(ngx.INFO, "cmd2: ", cmd2);
							os.execute(cmd2);
						end
					end
				end		
			end	
		end
	end
	return true;
end

local function rename_main()
	local request = {};
	--链接数据库
	if pool_mysql(request) ~= true then
		ngx.log(ngx.INFO, "mysql_connect failed");
		return false;
	end
	--查询数据库
	if select_mysql_info(request) ~= true then
		ngx.log(ngx.INFO, "select_mysql_info failed");
		return false;
	end
	--关闭数据库
	if close_mysql(request) ~= true then
		ngx.log(ngx.INFO, "close_mysql failed");
		return false;
	end
	return true;
end
rename_main()
