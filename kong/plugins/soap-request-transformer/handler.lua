local access = require("kong.plugins.soap-request-transformer.access")
local pretty = require("pl.pretty")
local concat = table.concat
local soap = require("soap")
local cjson = require("cjson")
local xml2lua = require("xml2lua")
local handler = require("xmlhandler.tree")
local insert = table.insert
local remove = table.remove

local SoapTransformerHandler = {
    VERSION = "0.0.1",
    PRIORITY = 801,
}

local function remove_attr_tags(e)
    if type(e) == "table" then
        for k, v in pairs(e) do
            if k == '_attr' then
                e[k] = nil
            end
            remove_attr_tags(v)
        end
    end
end

function SoapTransformerHandler:access(conf)
    access.execute(conf)
end

function SoapTransformerHandler:header_filter(conf)
    kong.response.clear_header("Content-Length")
    kong.response.set_header("Content-Type", "application/json")
end

function SoapTransformerHandler:body_filter(conf)
    local ctx = ngx.ctx
    local chunk, eof = ngx.arg[1], ngx.arg[2]

    ctx.rt_body_chunks = ctx.rt_body_chunks or {}
    ctx.rt_body_chunk_number = ctx.rt_body_chunk_number or 1

    if eof then
        local chunks = concat(ctx.rt_body_chunks)
        local parser = xml2lua.parser(handler)
        parser:parse(chunks)
        local t = handler.root["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]
        if conf.remove_attr_tags then
            remove_attr_tags(t)
        end

        ngx.arg[1] = cjson.encode(t)
    else
        ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
        ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
        ngx.arg[1] = nil
    end
end


return SoapTransformerHandler
