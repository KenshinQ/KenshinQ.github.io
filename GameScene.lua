local M = class("GameScene", function()
    return cc.Scene:create()
end)
M.TAG = "GameScene"

local Menu = require "game.modules.game.Menu"
local CardsType = require "game.modules.game.CardsType"

function M:ctor(data, isReset)
    local node = cc.CSLoader:createNode("ui/game/game.csb")
    self.root = node:getChildByName("root")
    node:ignoreAnchorPointForPosition(false)
    node:setAnchorPoint(cc.p(0.5, 0.5))
    node:setPosition(cc.p(display.cx, display.cy))
    local size = cc.Director:getInstance():getVisibleSize()
    node:setContentSize(size)
    ccui.Helper:doLayout(node)
    self:addChild(node)
    winMgr.setScene(self)
    self:initUI(data, isReset)
    self:initBtnEvent()
    self:initChest()
    self:update(data, isReset)
end

function M:initUI(data, isReset)
    --隐藏SNG排行按钮
    self.root:getChildByName("btn_sng_rank"):setVisible(false)
    local Table = require "game.modules.game.Table"
    -- Table.OperateUI = require "game.modules.game.OperateUI"
    -- Table.User = require "game.modules.game.User"
    self.table = Table.new(self.root)
    self.menu = Menu.new(self.root:getChildByName("menu_container"))
    self.cardsType = CardsType.new(self.root:getChildByName("cards_type_container"))
    self.btn_cards_type = self.table.btn_cards_type
   
    
end

function M:initChest()
    self.effect = nil
    self.btn_chests = self.root:getChildByName("btn_chests")
    self.effect_container = self.root:getChildByName("effect_container_1")
    self.btn_chests:setSwallowTouches(false)
    utils.addClickEvent(self.btn_chests, function()
        app.sendNotice(N_SHOW_CHESTS, { startPos = cc.p(self.btn_chests:getPosition()) })
        app.sendNotice(N_TRACKEVENT, { eventId = "btnRoomChests", data1 = 0, data2 = 0, data3 = 0, data4 = "" })
    end )
end

function M:initBtnEvent()
    utils.addClickEvent(self.root:getChildByName("btn_menu"), function(args) self.menu:show() end)
    utils.addClickEvent(self.root:getChildByName("btn_chat"), function(args)
        app.sendNotice(N_SHOW_CHAT, { })
        app.sendNotice(N_TRACKEVENT, { eventId = "btnRoomChat", data1 = 0, data2 = 0, data3 = 0, data4 = "" })
    end )
    utils.addClickEvent(self.root:getChildByName("btn_shop"), function(args)
        app.sendNotice(N_OPEN_ROOMSHOP,{})
        app.sendNotice(N_TRACKEVENT, { eventId = "btnRoomShop", data1 = 0, data2 = 0, data3 = 0, data4 = "" })
    end )
    if self.btn_cards_type then
        local function e(sender, eventType)
            if eventType == ccui.TouchEventType.began then
                self.cardsType:show( function() end)
                soundMgr.playEffect(2001)
            end
        end
        self.btn_cards_type:addTouchEventListener(e)
    end

    self.backBtnCall = function()
        if self.menu:isVisible() then
            self.menu:_hide()
        else
            self.menu:show()
        end
    end
end

function M:onRoundStart(data)
    self.table:onRoundStart(data)
end

function M:onRoundEnd(data)
    self.table:onRoundEnd(data)
end

function M:update(data, isReset)
    self.table:update(data, isReset)
end

function M:setChestsEffect(isShow)
    if not utils.isValid(self.effect_container) then
        logd(M.TAG,"self.effect_container is nil")
        return 
    end
    if isShow then
        if not self.effect then
            self.effect = cc.Sprite:create("effect/light_1.png")
            self.effect:runAction(cc.RepeatForever:create(cc.RotateBy:create(4, 360)))
            local p = cc.p(self.effect_container:convertToNodeSpace(cc.p(self.btn_chests:getPosition())))
            self.effect:setPosition(p)
            self.effect_container:addChild(self.effect)
        end
    else
        if self.effect then
            self.effect_container:removeChild(self.effect)
            self.effect = nil
        end
    end
end

return M
