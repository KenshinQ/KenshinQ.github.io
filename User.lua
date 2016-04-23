-----------------------
-- 玩家类
-----------------------
local M = class("User")
M.TAG = "User"

--M.userStatusPos = nil --显示状态UI
M.ACTIONS = {
    HIDE = "_hide",
    SHOW_SEAT_BTN = "_showSeatBtn",
    GAME_READY = "_gameReady",
    GAME_START = "_gameStart",
    OPERATO_START = "_operateStart",
    OPERATO_STOP = "_operateStop",
    CALL = "_call",
    CHECK = "_check",
    RAISE = "_raise",
    ALLIN = "_allin",
    FOLD = "_fold"
}


local LEFT_CARD_CONTAINER_X = -27
local RIGHT_CARD_CONTAINER_X = 128
local LEFT_GIFT_X = -75
local RIGHT_GIFT_X = 76
-- 处理UI的状态用于UI更新
M.UI_STATUS = {
    HIDE = 0,
    SHOW_SEAT_BTN = 1,
    READY = 2,
    START = 3,
    OVER = 4
}

-- 状态恢复 1=玩牌中 2=已弃牌 3=已坐下并等待中 update中用到
M.GAME_STATUS = {
    START = 1,
    FOLD = 2,
    READY = 3,
}
M.UserStatus = require "game.modules.game.UserStatus"
M.UserLight = require "game.modules.game.UserLight"

local Action = require "libgame.ai.Action"
local Cards = require "game.modules.game.Cards"
local Chip = require "game.modules.game.Chip"
local Bubble = require "game.modules.chat.Bubble"
local Face = require "game.modules.chat.Face"
local GiftIcon = require "game.modules.shopProp.GiftNode"

local scheduler = cc.Director:getInstance():getScheduler()

function M:ctor(view,posClient,cardPos,allTime,myClientPos)
    logd(M.TAG,"ctor...")
    self._cardPos = cardPos -- 桌子扑克起始位置
    self._allTime = allTime -- 可操作的配置时间
    self._myClientPos = myClientPos --3 或者是 5
    self.tableOriginPoint = cc.p(display.width/2,display.height*0.6)
    self.betChipsContenter = cc.Node:create()
    self:_initAction()
    self.view = view 
    if  not self.view then
        self.view = cc.CSLoader:createNode("ui/nodes/game_user.csb")
    end
    self.posClient = posClient
    self:_initUI(self.posClient)
    self:_initEvent()
    self:reset()
end
function M:ctor(nativeSeatId,selfNativeSeatId,cardPosition,pourContainer)
    logd(M.TAG,"create User")
    logd(M.TAG,string.format("user at seat %s when selfSeat at %s",nativeSeatId,selfNativeSeatId))
    self.tableOriginPoint = cc.p(display.width/2,display.height*0.6) 
    self.cardPosition = cardPosition
    self.m_game = app.getModel(M_Game).table.config.betTime
    self.nativeSeatId = nativeSeatId
    self.selfNativeSeatId = selfNativeSeatId
    self.pour_container = pourContainer
    self.view = cc.CSLoader:createNode("ui/game/user.csb")
    self.startPoint = cc.p(self.view:getPosition())
    self:_initAction()
    self:_initUI(self.nativeSeatId)
    self:_initEvent()
    self:reset()
end


-- public method
function M:mountTo(container,position)
    container:addChild(self.view)
    self.view:setPosition(position)
end

function M:seatDown()
    self:_operateStop()
    self.view:stopAllActions()
    self.view:setPosition(self:_getEndPoint())
    local sitPosition = self.startPoint
    local sitAction = cc.MoveTo:create(0.2, sitPosition)
    self.view:runAction(sitAction)
end

function M:seatUp()
    self.view:stopAllActions()
    local standUpAction = cc.MoveTo:create(0.2, self:_getEndPoint())
    self.view:runAction(standUpAction)
    self:reset()
    self.info = nil
end

-----------------------
-- 更新信息
-----------------------
function M:update(info)
    logd(M.TAG, string.format("user at seat %s update======= info %s",self.nativeSeatId,tostring(info)))
    self.info = info
    if not info then
        self:reset()
        return
    end
    dump(self.info,string.format("user at seat %s", self.nativeSeatId),3)
    self.uiStatus = M.UI_STATUS.START
    --    self.action:execute(M.ACTIONS.GAME_READY)
    if self.info.status == GAME_USER_STATUS.GAME_PLAYING then
        self.action:goto(M.ACTIONS.GAME_READY)
        self.action:execute(M.ACTIONS.GAME_START)
        
    elseif self.info.status == GAME_USER_STATUS.GAME_FOLD then
        self.action:goto(M.ACTIONS.GAME_START)
        self.action:execute(M.ACTIONS.FOLD)
        
    elseif self.info.status == GAME_USER_STATUS.GAME_WAITTING then
        self.action:goto("root")
        self.action:execute(M.ACTIONS.GAME_READY)
    end
    self:updateBaseUI()
    self:_resetCrads()
    self:updateGiftIcon()
    self.user_head:loadIcon(info.user.icon)
    self.view:stopAllActions()
    self.view:setPosition(self.startPoint)
end

-----------------------
-- 根据Action类型更新UI
-----------------------
function M:updateByAction(actionName, data, gotoActionName)
    if not self.info then return end
    self:_showStatusEffect(actionName)
    logd(M.TAG, string.format("user at seat %s when server seatId:%s uin:%s updateByAction %s", self.nativeSeatId, self.info and self.info.seatId or "NULL", self.info and self.info.user.uid or "NULL", actionName))
    self.action:execute(actionName, data, gotoActionName)
end
-----------------------
-- 选定为操作者
-----------------------
function M:_operateStart(operateDuration)
    loge(M.TAG, string.format("user at seat %s when server seatId: %s _operateStart time %s", self.nativeSeatId, self.info and self.info.seatId or "nil",time))

    if self.uiStatus == M.UI_STATUS.OVER then
        -- 如果设定我为操作者，但是我可能是弃牌了
        loge(M.TAG, string.format("user gameStatus %s", self.gameStatus))
        return
    end

    if not utils.isValid( self.ligth) then
        self.ligth = M.UserLight.new()
        self.view:addChild(self.ligth)
        if self.headScale == 1 then
            self.ligth:setScale(1.3)
        end
    end
    local sp = cc.p(self.startPoint.x - self.tableOriginPoint.x,self.startPoint.y - self.tableOriginPoint.y)
    self.ligth:show( - math.deg(getAngle(sp)))

    self.user_head:showOperateProgress(self._allTime,operateDuration)
    local function f()
        self:_stopOperateAlert()
        if not self.user_head:isOperating() or not tolua.cast(self.cards, "cc.Node") then 
            return 
        end
        self:_execOperateAlert()
    end

    self:_initOperateAlert()
    local minTime = 3
    if time > minTime then
        self:_stopOperateAlert()
        self.operateAlert.action = performWithDelay(self.view, function()
            -- 时间到倒计时前3秒时就开始提醒用户
            f()
        end , time - minTime)
    else
        f()
    end
end

-----------------------
---操作结束
-----------------------
function M:_operateStop()
    if utils.isValid(self.ligth) then
        self.ligth:hide()
    end
    self.user_head:hideOperateProgress()
    self:_stopOperateAlert()
end

-----------------------
-- 游戏结束
-----------------------
function M:over(info)

    self.resultCallBack = function()
        dump(info)
        if self.uiStatus == M.UI_STATUS.OVER then return end --如果人走了则不显示了
        if not self.info or info.uid ~= self.info.user.uid then return end
        soundMgr.playEffect(info.chipCrement > 0 and 20 or 19)
        local gainChipView = require("game.modules.game.GainChipView").new(info.chipCrement,self.headScale)
        self.view:addChild(gainChipView,16)
        gainChipView:show()
    end
    self:_operateStop()
    return info.order > 0
end

-----------------------
-- 游戏结束,显示结果
-----------------------
function M:showResult()
    logd(M.TAG, string.format("user at seat %s  showResult", self.nativeSeatId))
    if self.resultCallBack then
        self.resultCallBack()
        self.resultCallBack = nil
    end
end

-----------------------
-- 添加一张牌
-----------------------
function M:addCard(cards, cs, isStarted)
    local strLog = string.format("user at seat %s",self.nativeSeatId)
    for i=1,#cards do
        strLog = string.format( " %s add Card[%d] %s",strLog,i,cards[i] )
    end
    logd(M.TAG,strLog)
    if not self.info then return end
    if not self.info.cardData then
        self.info.cardData = {}
    end
    utils.table.push(self.info.cardData,cards)
    -- self.info.cardData = info
    self.cards:addCard(cards, cs, isStarted)
end
-----------------------
--显示自己的牌
-----------------------
function M:showCards(info)
    logd(M.TAG, string.format("user at seat %s when server seatId:%s  showCards", self.nativeSeatId, self.info and self.info.seatId or "NULL"))
    if not self.info then return end --自己离开了
    if self.nativeSeatId == self.selfNativeSeatId and app.getModel(M_Game):isSelfByUid(self.info.user.uid) then return end
    if self.info and info and info.handCards then
        local data = array.split(info.handCards, ",")
        logd(M.TAG, string.format("cards : 1 -> %s   2 -> %s ", data[1], data[2]))
        self.cards:show(data,(self.selfNativeSeatId and info.scoreCards or nil))
        self.info.cardData = data -- 用于结算过程中用户站起又坐下的恢复
    end
end

-----------------------
-- 游戏结束比牌
-----------------------
function M:compareCards(info)
    logd(M.TAG, string.format("user at seat %s when server seatId:%s  compareCards", self.nativeSeatId, self.info and self.info.seatId or "NULL"))
    if self.info and info and info.handCards then
        self.img_status:setVisible(false)
        local data = array.split(info.handCards, ",")
        logd(M.TAG, string.format("cards : 1 -> %s   2 -> %s ", data[1], data[2]))
        self.cards:compare(data,(self.selfNativeSeatId and info.scoreCards or nil))
        self.info.cardData = data -- 用于结算过程中用户站起又坐下的恢复
    end
end

function M:upgrade()
    self.view:addChild(require("game.effect.Upgrade").new())
end

-----------------------
-- 桌子上的筹码飞到共池
-----------------------
function M:allChipTo(pos, cb)
    logd(M.TAG, string.format("user at seat %s allChipTo", self.nativeSeatId))
    self.bet_chip_container:setVisible(false)

    local chips = { }
    local count = self.betChipsContenter:getChildrenCount()
    for i = 1, count do
        local chipContainer = self.betChipsContenter:getChildByTag(i)
        for j = 1, chipContainer:getChildrenCount() do
            table.insert(chips, chipContainer:getChildByTag(j))
        end
    end

    count = #chips
    if count > 0 then soundMgr.playEffect(17) end

    local function f()
        if not tolua.cast(self.view, "cc.Node") or count == 0 then
            scheduler:unscheduleScriptEntry(self.handle3)
            return
        end

        local chip = chips[count]
        if  chip.owner then
            chip.owner:captureTo(cc.p(self.betChipsContenter:convertToNodeSpace(pos)), cb)
        end
        count = count - 1
    end
    self.handle3 = scheduler:scheduleScriptFunc(f, 0.05, false)
end
-- private method

-----------------------
-- 初始化UI
-----------------------
function M:_initUI(pos)
    self.view:setCascadeOpacityEnabled(true)
    self.img_status = self.view:getChildByName("img_status")
    self.txt_name = self.view:getChildByName("txt_name")
    self.txt_current_chip = self.view:getChildByName("txt_current_chip")
    
    self.img_banker = self.pour_container:getChildByName("img_banker")
    self.txt_pour_chip = self.pour_container:getChildByName("txt_pour_chip")
    self.pour_chip_container = self.pour_container:getChildByName("pour_chip_container")
        
    self:_initUserHead()
    self:_initCardContainer()
    self:_initGiftNode()   
end
function M:_initUserHead()
    local UserHead = require("game.modules.game.UserHead")
    self.user_head = UserHead.new(self.view:getChildByName("node_head"))
end
function M:_initCardContainer()
    self.other_card_container = self.view:getChildByName("other_card_container")
    self.self_card_container = self.view:getChildByName("self_card_container")
    self.other_cards = Cards.new(self.other_card_container)
    self.other_card_container:addChild(self.other_cards)
    self.self_cards = Cards.new(self.self_card_container)
    self.self_card_container:addChild(self.self_cards)
    
    self.self_card_container:setVisible(false)
    self.btn_cards_type = self.self_card_container:getChildByName("btn_card_type")
    local function isLeft( seatId )
        local maxLeftSeatId = math.floor((NUM_MAX_TABLE_SEAT)/2)+1
        if seatId <= maxLeftSeatId then
            return true
        end
        return false
    end
    if isLeft(self.nativeSeatId) then
        self.other_card_container:setPositionX(LEFT_CARD_CONTAINER_X)
    else
        self.other_card_container:setPositionX(RIGHT_CARD_CONTAINER_X)
    end
end
function M:_initGiftNode()
    self.node_gift = self.view:getChildByName("node_gift")
    local function isLeft( seatId )
        local maxLeftSeatId = math.floor((NUM_MAX_TABLE_SEAT)/2)
        if seatId <= maxLeftSeatId then
            return true
        end
        return false
    end
    if isLeft(self.nativeSeatId) then
        self.node_gift:setPositionX(LEFT_GIFT_X)
    else
        self.node_gift:setPositionX(RIGHT_GIFT_X)
    end
end

function M:_initEvent(args)
    utils.addClickEvent(self.img_head, function(args)
        if self.info then
            app.sendNotice(N_SHOW_USER_INFO, { type = app.getModel(M_Game):isSelfByUid(self.info.user.uid) and 1 or 2, uid = self.info.user.uid })
        end
    end )
end
-----------------------
-- 初始化行为
-----------------------
function M:_initAction()
    logd(M.TAG,"_initAction...")
    local function createAction(actionName)
        return Action.new(actionName, handler(self, self[actionName]))
    end
    local _actions = { }
    local actions = M.ACTIONS
    self.action = Action.new("root")
    for k, v in pairs(actions) do
        _actions[v] = createAction(v)
    end
    self.action:addActions( { _actions[actions.HIDE], _actions[actions.SHOW_SEAT_BTN], _actions[actions.GAME_READY] })
    _actions[actions.HIDE]:addActions( { _actions[actions.SHOW_SEAT_BTN], _actions[actions.GAME_READY] })
    _actions[actions.SHOW_SEAT_BTN]:addActions( { _actions[actions.GAME_READY], _actions[actions.HIDE] })
    _actions[actions.GAME_READY]:addActions( { _actions[actions.GAME_START], _actions[actions.HIDE] })
    _actions[actions.GAME_START]:addActions( { _actions[actions.GAME_READY], _actions[actions.OPERATO_START], _actions[actions.OPERATO_STOP], _actions[actions.CALL], _actions[actions.CHECK], _actions[actions.RAISE], _actions[actions.FOLD], _actions[actions.HIDE], _actions[actions.ALLIN] })
end
-----------------------
-- 重置
-----------------------
function M:reset()
    logd(M.TAG, string.format("user at seat :%s reset uiStatus %s nowAction %s", self.nativeSeatId, self.uiStatus, self.action.currentAction.name))
    self.uiStatus = M.UI_STATUS.HIDE
    if self.info then self.info.lastAction = "" end
    self:_unDark()
    self:_setOpacity(255)
    self:_operateStop()
    self:_hideBaseUI()
    self:_clear()
    if self.info then
        self.action:goto("root")
        self.action:execute(self.ACTIONS.GAME_READY)
    end
    self.img_status:setVisible(false)
    --self.betChipsContenter:removeAllChildren() --这个要异步清理
end

function M:_hideBaseUI()
    self.other_card_container:setVisible(false)
    self.self_card_container:setVisible(false)
    -- self.bet_chip_container:setVisible(false)
    -- self.info_container:setVisible(false)
    self.pour_container:setVisible(false)
    self.user_head:hide()
    self.img_status:setVisible(false)
    self.node_gift:setVisible(false)
    self.txt_name:setVisible(false)
    self.txt_current_chip:setVisible(false)
    self:_resetCrads()
end

local function getAngle(sp)
        function check(p)
            local l = math.sqrt(p.x * p.x + p.y * p.y)
            return l == 0 and { x = 1, y = 0 } or { x = p.x / l, y = p.y / l }
        end
        local p1, p2 = check(cc.p(0,0)), check(sp)
        local a = math.atan2(p1.x * p2.y - p1.y * p2.x, p1.x * p2.x + p1.y * p2.y)
        if math.abs(a) <(0.5 ^ 23) then a = 0 end
        return a
end

function M:_getEndPoint()
    local len = 300 * 2
    local sp = cc.p(self.startPoint.x - self.tableOriginPoint.x,self.startPoint.y - self.tableOriginPoint.y)
    local function getPointRotate(p, angle)
        local l = math.sqrt(p.x * p.x + p.y * p.y)
        return { x = l * math.cos(angle), y = l * math.sin(angle) }
    end
    sp = getPointRotate(cc.p(sp.x, ((sp.y < 0 and sp.y - len) or sp.y + len)), getAngle(sp))
    return cc.p(sp.x + self.tableOriginPoint.x, sp.y +self.tableOriginPoint.y)
end



-----------------------
-- 清理掉一些动态生成的东西
-----------------------
function M:_clear(args)
    if self.info then
        self.info.cardData = nil
    end
    if self.cards then
        self.cards:clear()
    end
    if utils.isValid( self.btn_cards_type) then
        self.btn_cards_type:setVisible(false)
    end
    -- self.betChipsContenter:removeAllChildren()
    self.pour_chip_container:removeAllChildren()
    self.txt_pour_chip:setString("")
end

-----------------------
-- 显示可以准备开始的UI
-----------------------
function M:updateBaseUI()
    if self.info and utils.isValid(self.view) then
        -- 延迟调用，可能会出现view 被释放了
        logd(M.TAG, string.format("user at native seat %s when server seatId: %s updateBaseUI", self.nativeSeatId, self.info.seatId))
        self.txt_name:setVisible(true)
        self.txt_current_chip:setVisible(true)
        if utils.isValid( self.btn_cards_type) then
            self.btn_cards_type:setVisible(self.info.cardData ~= nil)
        end
        if self:isSelf() then
            self.other_card_container:setVisible(false)
            self.cards_container = self.self_card_container       
            self.cards = self.self_cards
        else
            self.self_card_container:setVisible(false)
            self.cards_container = self.other_card_container
            self.cards = self.self_cards
        end
        self.cards_container:setVisible(true)
        self.node_gift:setVisible(true)
        self.user_head:show()
        self.txt_current_chip:setString(utils.format(self.info.nowChip, 1))
        if string.len(self.info.user.nick) <= 6 then
            self.txt_name:setString(self.info.user.nick)
        else
            self.txt_name:setString(string.sub(self.info.user.nick, 1, 6) .. "..")
        end
        self:_setStatus()
    else
        logd(M.TAG, string.format("user at seat :%s updateBaseUI info is nil", self.nativeSeatId))
    end
end
-----------------------
-- 设置头顶的状态
-----------------------
function M:_setStatus()
    -- logd(M.TAG, string.format("setStatus %s", self.info.lastAction))
    self:_checkStatus()
    self.img_status:setVisible(self.info and self.info.lastAction ~= "")
    if self.info.lastAction ~= "" then
        self.img_status:loadTexture("ui/game/game_user/" .. self.info.lastAction .. ".png")
    end
end

function M:_checkStatus()
    local strChange = nil
    -- 有可能是ALL IN 或者 FOLD
    if self.info.lastAction == "" then
        if self.info.status == GAME_USER_STATUS.GAME_FOLD then
            self.info.lastAction = USER_ACTION.GAME_FOLD
            strChange = "self.info.status == 2 self.info.lastAction = USER_ACTION.GAME_FOLD"
        elseif self.info.isAllin then
            self.info.lastAction = USER_ACTION.GAME_ALLIN
        elseif self.info.status == GAME_USER_STATUS.GAME_PLAYING then
            if app.getModel(M_Game):getRound() and app.getModel(M_Game):getRound().currStep == 0 then

            end
        end
        if strChange then
            logd(M.TAG, string.format("user at seat %s when server seatId: %s 手动改变用户状态 %s" ,self.nativeSeatId, self.info.seatId, strChange))
        end
    end
    if self.info.status == GAME_USER_STATUS.GAME_PLAYING and self.info.lastAction == USER_ACTION.GAME_FOLD then
        self.info.lastAction = ""
    end
end
-----------------------
-- 播放特效
-----------------------
function M:_showStatusEffect(actionName)
     logd(M.TAG, string.format("user at native seat %s when server seatId: %s _showStatusEffect %s", self.nativeSeatId, self.info.seatId ,actionName))
     M.UserStatus.new(self, actionName)
end
-----------------------
-- 获取庄家的位置
-----------------------
function M:getDealerPos()
    local dPos = cc.p(self.dealer:getPosition())
    return cc.p(self.startPoint.x + dPos.x, self.startPoint.y + dPos.y)
end

-- 操作倒计时时的提醒行为
-- 每个user只初始化一次
-- 用户修改设置（震动、音效）从下局开始生效
function M:_initOperateAlert()
    if self.operateAlert ~= nil then return end

    self.operateAlert = {
        isPlayVibrate = false,
        -- 是否震动
        isPlaySound = false,
        -- 是否音效
        action = nil,-- 对应的action句柄
    }

    local isSelf = false
    if self.info and self.info.user then
        isSelf = app.getModel(M_Game):isSelfByUid(self.info.user.uid)
    end

    if isSelf then
        if cc.UserDefault:getInstance():getBoolForKey("_vibrationStr", true) then
            self.operateAlert.isPlayVibrate = true
        end
    end

    -- 其他人也播放音效
    if cc.UserDefault:getInstance():getBoolForKey("_soundStr", true) then
        self.operateAlert.isPlaySound = true
    end
end

function M:_stopOperateAlert()
    if self.operateAlert and self.operateAlert.action and tolua.cast(self.operateAlert.action,"cc.Ref") then
        self.operateAlert.action:stop()
        self.view:stopAction(self.operateAlert.action)
        self.operateAlert.action = nil
    end
    if utils.isValid(self.ligth) then
        self.ligth:hide()
    end
end

function M:_execOperateAlert()
    if self.operateAlert.isPlayVibrate then
        -- 震动
        platform.playVibrate()
    end
    if self.operateAlert.isPlaySound then
        -- 播放音效
    end
end

-----------------------
-- 设置部分UI透明度
-----------------------
function M:_setOpacity(value)
    -- self.cards_container:setOpacity(value)
    -- self.info_container:setOpacity(value)
    -- self.img_head:setOpacity(value)
end

-----------------------
-- 获取接牌的位置
-----------------------
function M:getCardPos()
    return self.view:convertToWorldSpace(cc.p(self.cards_container:getChildByName("card_1"):getPosition()))
end



-----------------------
-- 准备中
-----------------------
function M:_gameReady()
    self.uiStatus = M.UI_STATUS.READY
    self:_unDark()
    self:_setOpacity(160)
    self:updateBaseUI()
end

-----------------------
-- 游戏开始
-----------------------
function M:_gameStart()
    logd(M.TAG, string.format("user at seat %s when server seatId: %s",self.nativeSeatId,self.info.seatId))
    self.uiStatus = M.UI_STATUS.START
    self:_setOpacity(255)
    self:_payChip(true)
    self:updateBaseUI()
end

-----------------------
-- 离开座位调用
-----------------------
function M:_hide()
    self.uiStatus = M.UI_STATUS.HIDE
    self.info = nil
    self:_operateStop()
    self:_hideBaseUI()
    self:_clear(args)
    if utils.isValid(self.chatUI) then 
        self.chatUI:removeFromParent() 
   end
end

-----------------------
-- 跟
-----------------------
function M:_call(chips)
    self:_operateStop()
    self:_payChip()
end

-----------------------
-- 过
-----------------------
function M:_check()
    self:_operateStop()
end

-----------------------
-- 加注
-----------------------
function M:_raise()
    self:_operateStop()
    self:_payChip()
end

-----------------------
-- allin
-----------------------
function M:_allin()
    -- logd(M.TAG,string.format("userClient_%s ====_allin====",self.posClient))
    self:_operateStop()
    self:_payChip()
end

-----------------------
-- 放弃
-----------------------
function M:_fold()
    self:_operateStop()
    self.cards:fold(M.cardPos, self.nativeSeatId)
    self:_dark()
end

function M:chat(data)
   if utils.isValid(self.chatUI) then 
        self.chatUI:removeFromParent() 
   end
   self.chatUI = (data.type == 2 and Face.new(data.content, self.headScale * 1.4)) or Bubble.new(data.content,self.nativeSeatId)
   self.view:addChild(self.chatUI,9999)
end



function M:_getChipPos()
    return cc.p(0, 0)
end

function M:_payChip(isStarted)
    logd(M.TAG, string.format("user at seat %s when server seatId: %s _payChip isStarted %s nowBet %s ", self.nativeSeatId, self.info.seatId, tostring(isStarted), tostring(self.info.nowBet)))
    if self.info.nowBet == 0 then return end
    local nowBet = self.info.nowBet
    local add = self.info.nowBet
    function backTo(pos, cb)
        logd(M.TAG,"payChip->do chip backTo")
        local chips = { }
        local count = self.betChipsContenter:getChildrenCount()
        if count == 0 then cb() return end
        for i = 1, count do
            local chipContainer = self.betChipsContenter:getChildByTag(i)
            for j = 1, chipContainer:getChildrenCount() do
                table.insert(chips, chipContainer:getChildByTag(j))
            end
        end
        for i = 1, #chips do
            chips[i].owner:backTo(pos, i == 1 and cb or nil)
        end
    end

    -- logd(M.TAG,string.format("userClient_%s seatId: %s _payChip isStarted %s",self.posClient,self.info.seatId,tostring(isStarted)))
    local endPos = cc.p(self.bet_chip_container:getPosition())
    local startPos =  self:_getChipPos()
    dump(startPos)
    local function addChip()
        soundMgr.playEffect(5)
        local chips = { }
        local chip
        local index = 1
        local chipContenter = cc.Node:create()
        local count = 5

        while add > 0 and count > 0 do
            if CHIP_VALUE[index] > add then
                add = add - (CHIP_VALUE[index - 1] or CHIP_VALUE[1])
                table.insert(chips, CHIP_VALUE[index - 1])
                index = 1
                count = count - 1
            else
                index = index + 1
            end
        end

        dump(chips)
        if isStarted then
            self.bet_chip_container:setVisible(true)
            self.lab_bet_chip:setString(utils.format(nowBet,1))
            for i = 1, #chips do
                chip = Chip.new(chips[i])
                chip.view:setTag(i)
                 cc.p(chip.view:setPosition(endPos.x + math.random(-3, 3), endPos.y +(chipContenter:getChildrenCount() + i) * 2))
                chipContenter:addChild(chip.view)
            end
        else
            chipContenter:removeAllChildren()
            for i = 1, #chips do
                chip = Chip.new(chips[i])
                chip.view:setTag(i)
                local p = startPos
                p.x = p.x + math.random(-3, 3)
                p.y = p.y +(i - 1) * 2
                chip.view:setPosition(p)
                p = endPos
                p.x = p.x + math.random(-3, 3)
                p.y = p.y +(i - 1) * 2
                chip:moveTo(p, function()
                    self.bet_chip_container:setVisible(true)
                    self.lab_bet_chip:setString(utils.format(nowBet,1))
                end )
                chipContenter:addChild(chip.view)
            end
        end

        chipContenter:setTag(self.betChipsContenter:getChildrenCount() + 1)
        self.betChipsContenter:addChild(chipContenter)
    end
    if self.info.lastCount > 0 and self.info.lastCount ~= add then
        backTo(startPos, function()
            logd(M.TAG, string.format("user at seat %s ===backTo===", self.nativeSeatId))
            addChip()
        end )
    else
        addChip()
    end
end

function M:updateGiftIcon()
    --礼物图标
    if not self.giftIcon then
        self.giftIcon = GiftIcon.new()
        self.node_gift:addChild(self.giftIcon)
     end
     if self.info then
         self.giftIcon:setUserInfo(self.info.user)
     end
end

function M:markCards()
    self.cards:markCards()
end

-----------------------
-- 变灰
-----------------------
function M:_dark()
    self.bet_chip_container:setColor(cc.c3b(150, 150, 150))
    self.info_container:setColor(cc.c3b(150, 150, 150))
    
    self.cards_container:setColor(cc.c3b(150, 150, 150))
    self.img_status:setColor(cc.c3b(150, 150, 150))
    self.gift:setColor(cc.c3b(150, 150, 150))
    self.user_head:toDark()
end

-----------------------
-- 取消变灰
-----------------------
function M:_unDark()
    self.bet_chip_container:setColor(cc.c3b(255, 255, 255))
    self.info_container:setColor(cc.c3b(255, 255, 255))
    
    self.other_card_container:setColor(cc.c3b(255, 255, 255))
    self.self_card_container:setColor(cc.c3b(255, 255, 255))
    self.img_status:setColor(cc.c3b(255, 255, 255))
    self.gift:setColor(cc.c3b(255, 255, 255))
    self.user_head:toUnDark()
end

-----------------------
-- 恢复牌
-----------------------
function M:_resetCrads()
    if self.info then
        self.cards:setData(self.info.cardData or { nil, nil })
    end
end

-----------------------
-- 是否需要给我牌
-----------------------
function M:needCard()
    return  self.info and self.info.status ~= GAME_USER_STATUS.GAME_WAITTING and self.cards:needCard()  
end

-----------------------
-- 是不是自己
-----------------------
function M:isSelf()
    return  self.info and app.getModel(M_Game):isSelfByUid(self.info.user.uid)
end
return M