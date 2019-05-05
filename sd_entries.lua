-- File : sd_entries.lua
-- Who  : Jose Amores 
-- What : SD subdissector in charge of parsing Entries within at EntriesArray
--
local p_sd_ents = Proto("sd_entries","sd_entry")

local f_e_type      = ProtoField.uint8("sd.e.type","Type",base.HEX)
local f_e_o1_i      = ProtoField.uint8("sd.e.opt1_i","Index 1st options",base.HEX)
local f_e_o2_i      = ProtoField.uint8("sd.e.opt2_i","Index 2nd options",base.HEX)
local f_e_o1_n      = ProtoField.uint8("sd.e.opt1_n","# opt 1",base.HEX,nil,0xf0)
local f_e_o2_n      = ProtoField.uint8("sd.e.opt2_n","# opt 2",base.HEX,nil,0x0f)
local f_e_srv_id    = ProtoField.uint16("sd.e.srv_id","Service ID",base.HEX)
local f_e_inst_id   = ProtoField.uint16("sd.e.inst_id","Instance ID",base.HEX)
local f_e_v_major   = ProtoField.uint8("sd.e.v_major","MajorVersion",base.HEX)
local f_e_ttl       = ProtoField.uint24("sd.e.ttl","TTL",base.DEC)
local f_e_v_minor   = ProtoField.uint32("sd.e.v_minor","MinorVersion",base.HEX)
local f_e_reserved  = ProtoField.uint8("sd.e.reserved","Reserved",base.HEX)
local f_e_init_req  = ProtoField.bool("sd.e.init_req","Initial Data Requested Flag")
local f_e_reserved2 = ProtoField.uint8("sd.e.reserved2","Reserved2",base.HEX,nil,0x07)
local f_e_cnt       = ProtoField.uint8("sd.e.cnt","Counter",base.DEC,nil,0x0f)
local f_e_egrp_id   = ProtoField.uint8("sd.e.egrp_id","EventGroup_ID",base.HEX)

local e_types = {
    [0] = "FIND SERVICE",   -- 0x00
    [1] = "OFFER SERVICE",  -- 0x01
    [6] = "SUBSCRIBE",      -- 0x06
    [7] = "SUBSCRIBE ACK"   -- 0x07
}

local e_negative_types = {
    [1] = "STOP OFFER SERVICE",  -- 0x01
    [6] = "STOP SUBSCRIBE",      -- 0x06
    [7] = "SUBSCRIBE NACK"   -- 0x07
}

p_sd_ents.fields = {f_e_type,f_e_o1_i,f_e_o2_i,f_e_o1_n,f_e_o2_n,f_e_srv_id,f_e_inst_id,f_e_v_major,f_e_ttl,f_e_v_minor,f_e_reserved,f_e_init_req,f_e_reserved2,f_e_cnt,f_e_egrp_id}

function p_sd_ents.dissector(buf,pinfo,root)
    local offset = 0

    -- length of EntriesArray
    local e_len = buf(offset,4):uint()
    offset = offset + 4

    -- parse entries  (NOTE : some extra variables to easen understanding)
    local e_len_parsed = 0
    local info_col = ""
    while e_len_parsed < e_len do
        local i_parse, e_type_u8, ttl  = parse_entries(root,buf(offset,(e_len - e_len_parsed)))
        e_len_parsed = e_len_parsed + i_parse
        if (ttl ~= 0) then
            info_col = info_col .. e_types[e_type_u8] .. ", "
        else
            info_col = info_col .. e_negative_types[e_type_u8] .. ", "
        offset = offset + i_parse
        end
    end

    if (info_col ~= "") then
        -- Replace info column
        pinfo.cols.info = info_col:sub(0, -3)
    end
end

function is_entry_service(type_u8)
    -- TODO : remove this magic numbers
    if ((type_u8 == 0x00) or (type_u8 == 0x01)) then
        return(true)
    else
        return(false)
    end
end

function parse_entries(subtree,buf)
    local offset = 0

    local e_subtree = subtree:add(p_sd_ents)
    --Type
    local type_tree = e_subtree:add(f_e_type,buf(offset,1))
    local type_u8 = buf(offset,1):uint()
    if e_types[type_u8] ~= nil then
        type_tree:append_text(" ("..e_types[type_u8]..")") 

        -- also update "root" with entry type
        e_subtree:append_text(" : "..e_types[type_u8])
    else
        type_tree:append_text(" (type unknown)") 
    end
    offset = offset + 1

    -- Index 1st options
    e_subtree:add(f_e_o1_i,buf(offset,1))
    offset = offset + 1
    -- Index 2nd options
    e_subtree:add(f_e_o2_i,buf(offset,1))
    offset = offset + 1

    -- Num of opt 1 (NOTE : no increase in offset position, 4bit field)
    e_subtree:add(f_e_o1_n,buf(offset,1))
    -- Num of opt 2
    e_subtree:add(f_e_o2_n,buf(offset,1))
    offset = offset + 1

    -- ServiceID
    e_subtree:add(f_e_srv_id,buf(offset,2))
    offset = offset + 2
    -- InstanceID
    e_subtree:add(f_e_inst_id,buf(offset,2))
    offset = offset + 2

    -- Major version
    e_subtree:add(f_e_v_major,buf(offset,1))
    offset = offset + 1 
    -- TTL
    e_subtree:add(f_e_ttl,buf(offset,3))
    local ttl = buf(offset,3):uint()
    offset = offset + 3 

    -- SERVICE / EVENTGROUP entries
    if is_entry_service(type_u8) then
        -- SERVICE
        -- Minor Version
        e_subtree:add(f_e_v_minor,buf(offset,4))
        offset = offset + 4
    else
        -- EVENTGROUP
        -- Reserved
        e_subtree:add(f_e_reserved,buf(offset,1))
        offset = offset +1

        --Initial Data Requested Flag && Reserved2 && Counter
        e_subtree:add(f_e_init_req,buf(offset,1):bitfield(0,1))
        e_subtree:add(f_e_reserved2,buf(offset,1))
        e_subtree:add(f_e_cnt,buf(offset,1))
        offset = offset + 1

        -- EventGroup ID
        e_subtree:add(f_e_egrp_id,buf(offset,2))
        offset = offset + 2
    end

    return offset, type_u8, ttl
end
