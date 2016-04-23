-----------------------
-- 赌桌类
-----------------------
local M = class("Table")
M.TAG = "Table"

M.OperateUI = require "game.modules.game.OperateUI"
M.User = require("game.modules.game.User")
local Card = require "game.modules.game.Card"
local Interact = require("game.effect.Interact")

local Light = require("game.modules.game.Light")
local QuicChat = require "game.modules.chat.QuickChat"

local DEAL_TIME = 0.16 --一个人的发牌时间
local m_game = app.getModel(M_Game)
local scheduler = cc.Director:getInstance():getScheduler()
local isResetData = false -- 重新设置数据，这可能是切换到后台之后切回到前台
local oldOffest = 0  -- 这个值只在切后台回来，自己又没有在桌子上时候有用
local size = cc.Director:getInstance():getWinSize()
-- 庄家位置
M.dealerPos = { cc.p(98, - 10), cc.p(50, - 20), cc.p(18, - 32), cc.p(-90, 6), cc.p(209, 21), cc.p(90, 6), cc.p(-18, - 32), cc.p(-58, - 20), cc.p(-98, - 10) }

-- 玩家位置
M.userPositions = {
    [6] = cc.p(327,207),
    [1] = cc.p(877,640),
    [2] = cc.p(1105,54),
    [3] = cc.p(1139,328),
    [4] = cc.p(977,207),
    [5] = cc.p(50,207),
    [7] = cc.p(144,330),
    [8] = cc.p(172,538),
    [9] = cc.p(395,640)
}

-- 最后显示在桌面上的用户位置
M.userLocal9 = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } -- 九个人的座位
M.userLocal6 = { 1, 4, 5, 6, 7, 9 } -- 六个人的座位
M.userLocal2 = {1,5}
-- 玩家排序
M.zOrder9 = { 1, 9, 2, 8, 3, 7, 4, 6, 5 }
M.zOrder6 = { 1, 6, 2, 5, 4, 3 }
M.zOrder2 = {1,2}
function M:ctor(view)
    logd(M.TAG,"create Table")
    m_game = app.getModel(M_Game)
    dump(m_game)
    self.view = view
    self.maxUser = m_game.table.config.maxUser

    assert(self.maxUser == 6 or self.maxUser == 9 or self.maxUser == 2, "m_game.table.config.maxUser error")

    if self.maxUser == 9 then
        self.userLocalPos = M.userLocal9
    elseif self.maxUser == 6 then
        self.userLocalPos = M.userLocal6
    else
        self.userLocalPos = M.userLocal2
    end
    --self.userLocalPos =(self.maxUser == 9 and M.userLocal9) or M.userLocal6
    -- 我的位置索引
    self.myPosIndex =(self.maxUser == 9 and 5) or 3
    if self.maxUser == 2 then
        self.myPosIndex = 2
    end

    -- 结算后的快速聊天记录数据
    self.quickChatData = { }
    -- 本地的玩家顺序列表
    self.usersClient = { }
    --服务器的玩家顺序列表
    self.usersServer = { }
    -- -- 转圈后的玩家实例
    -- self.usersClient = { }
    -- 庄家的icon 要放的坐标
    self.bankerPosList = { }
    -- 玩家的坐标,还携带补间坐标
    self.userPos = { }

    self.spr_banker = view:getChildByName("spr_banker")
    local bx, by = self.spr_banker:getPosition()
    self.spr_banker:setPosition(cc.p(bx + 30, by - 30))
    
    self.cardStartPos = cc.p(view:getChildByName("table"):getPosition())
    self.cardStartPos.y = self.cardStartPos.y + 150
 
    
    self.users_container = view:getChildByName("users_container")
    self.cards_container = view:getChildByName("cards_container")
    self.cards_container:setPositionX(display.cx - 10)
    self.cards_container:setRotation3D(cc.vec3(-18, 0, 0))
    self.lab_table_info = view:getChildByName("lab_table_info")
    self.all_chip = view:getChildByName("all_chip")
    self.btn_chat = view:getChildByName("btn_chat")
    self.btn_menu = view:getChildByName("btn_menu")
    self.btn_seatdown = view:getChildByName("btn_seatdown")
    self.btn_seatdown:setVisible(false)

    utils.addClickEvent(self.btn_seatdown, function(sender)
        sender:setVisible(false)
        msgMgr.sendMsg(MSG_GAME_SITDOWN, { deskId = app.getModel(M_Game).table.config.deskId })
        utils.addDelayCall(function()  
            if utils.isValid(self.view) then
                self:_checkSeatBtn()
            end
          end,4)
    end )

    self.effect_container = view:getChildByName("effect_container_1")
    
    self.allChipPos = cc.p(self.all_chip:getChildByName("img_chip_icon"):getPosition()) --cc.p(self.all_chip:getPosition())
    --self.allChipPos.y = self.allChipPos.y - 33
    self.light = Light.new()
    local size = self.users_container:getContentSize()
    local lightPos = cc.p(self.users_container:getPosition())
    lightPos.y = lightPos.y + 30
    self.light:setPosition(lightPos)
    self.users_container:addChild(self.light, -1)

    for i = 1, 9 do
        local userView = self.users_container:getChildByName("user_" .. i)
        userView:setVisible(false)
        userView.absPos = i
    end
    
    for i = 1, #self.userLocalPos do
        local user = M.User.new(self.users_container:getChildByName("user_" .. self.userLocalPos[i]), i, self.cardStartPos, m_game.table.config.betTime, self.myPosIndex)
        user.view:setVisible(true)
        self.usersClient[i] = user
    end
    self.other_pos5_user = M.User.new(self.users_container:getChildByName("user_5_1"), self.myPosIndex, self.cardStartPos, m_game.table.config.betTime, self.myPosIndex)
    self.self_pos5_user = self.usersClient[self.myPosIndex]
    
    local children = self.view:getChildren()
    for i = 1 ,# children do
        children[i]:setLocalZOrder(i)
    end

    local cz ,uz = self.cards_container:getLocalZOrder(),self.users_container:getLocalZOrder()

    self.cards_container:setLocalZOrder(uz)
    self.users_container:setLocalZOrder(cz)

    self:_order()
    self.btn_cards_type = self.usersClient[self.myPosIndex].view:getChildByName("btn_cards_type")
    Interact.doLoadFile()
    self.operateUI = M.OperateUI.new(view:getChildByName("btns"), function(visible) self.btn_chat:setVisible(visible) end,function () self:_stopOperate() end)
    self:_reset()
    self:_playAnim()
end

function M:_order()
    for i = 1, #M["zOrder" .. self.maxUser] do
        self.usersClient[M["zOrder" .. self.maxUser][i]].view:setLocalZOrder(i)
    end
end

function M:_checkMyPosUser()
     logd(M.TAG, "_checkMyPosUser")
    local function swop(arr,a,b)
        for i = 1, #arr do
            if arr[i] == a then
                arr[i] = b 
                return
            end
        end
    end

     local selfIsIn = m_game:getSelfDeskInfo() ~= nil
    if not selfIsIn then
        swop(self.usersServer,self.usersClient[self.myPosIndex],self.other_pos5_user)
        self.usersClient[self.myPosIndex] = self.other_pos5_user
    else
        swop(self.usersServer,self.usersClient[self.myPosIndex],self.self_pos5_user)
        self.usersClient[self.myPosIndex] = self.self_pos5_user
    end
    self.other_pos5_user.view:setVisible(not selfIsIn)
    self.self_pos5_user.view:setVisible(selfIsIn)
end

function M:_updateAllUser()
    self:_checkMyPosUser()
     -- 设置玩家
    for i = 1, #self.usersServer do
        if m_game.table.users["seat" .. i] then
            if m_game.table.status ~= GAME_STATUS.START then
                -- 游戏还没开始需要清理掉后台的冗余数据
                m_game.table.users["seat" .. i].lastAction = ""
            end
            -- self:_seatDown(m_game.table.users["seat" .. i].seatId)
        end
--        dump(self.usersServer[i],"user_"..i,3)
        self.usersServer[i]:update(m_game.table.users["seat" .. i])
    end
end     

function M:addCards( cards )
    if not self.myCards then
        self.myCards = {}
    end
    if cards then
        utils.table.push(self.myCards,cards)
    end
end
-- 更新整张桌子
function M:update(data, isReset)
    isResetData = isReset
    data = data or app.getModel(M_Game).table
    -- 如果没有data则为自己刚刚坐下
    local myIs_seatDown = m_game:getSelfDeskInfo()
    self:_convertUserPos()
    self:_updateAllUser()

    if m_game.table.status == GAME_STATUS.START then
        winMgr.hideLoading()
        self:_showAllChip()
        if data.handCards then
            m_game:setHandCards(array.split(data.handCards, ","))
            self.myCards = array.split(data.handCards, ",")
            logd(M.TAG, string.format("update m_game.table.status == GAME_STATUS.START myCards : card1 --> %s card2 --> %s", self.myCards[1], self.myCards[2]))
        end
        self:_showPublicCards(true)
        self:_setDealer(true)
        self:_deal(true)
        self:_nowChip()
        self:_setOperate()
    else
        self:_showCardsType()
        self:showLoading(nil, nil, false)
    end

    self:_checkSeatBtn()
    -- 设置显示大小盲
    self:_showTableInfo()
    isResetData = false

end

-- 坐下
function M:_seatDown(seatId, isSelf)
    if isSelf then
        self:_convertUserPos()
        self:_updateAllUser()
        self:_deal(true)
        if m_game.table.status == GAME_STATUS.START then
            self:_setDealer()
            self:_setOperate()
        end
        -- logd(M.TAG,string.format("seatId %s",seatId))
    else
        self:_checkMyPosUser()
        self.usersServer[seatId]:update(m_game.table.users["seat" .. seatId])
    end
--    if self.usersServer[seatId] == self.usersClient[self.myPosIndex] then
--        self.other_pos5_user.view:setVisible(true)
--    end
    self.usersServer[seatId]:seatDown()
    self:_checkSeatBtn()
end

-- 站起
function M:_seatUp(seatId, isSelf)
    logd(M.TAG,string.format("_seatUp seatId %s isSelf %s",seatId,isSelf))
    if isSelf then self:_hideQuickChat() end
    local user = self.usersServer[seatId]
    if m_game.table.status == GAME_STATUS.START then
        user:allChipTo(cc.p(self.allChipPos.x, self.allChipPos.y + 40), function(add) end)
--        user:reset()
    end
    user:seatUp()
    self:_checkSeatBtn()
end
 
-- 检查是否要显示坐下的按钮
function M:_checkSeatBtn()
    self.btn_seatdown:setVisible(m_game:getSelfDeskInfo() == nil and not self.roundEndPalying)
end

-- 游戏开始了
function M:_getLastInfo(data)
    winMgr.tips( { txt = gameTxt.net.tips2, style = "top", time = 9 })
    self.endCallBack = function()
        msgMgr.sendMsg(MSG_GAME_GETDESKLASTINFO, { deskId = m_game.table.config.deskId })
    end
end

-- 游戏开始了
function M:onRoundStart(data)
    release_print("onRoundStart")
    dump(data)
    
    --如果开始游戏的事件过早发下来则在播放完动画就从新链接游戏
    if self.roundEndPalying then
        self:_getLastInfo()
        return
    end

    -- =================解决后台删掉roundInfo的问题====================-
    for k, v in pairs(m_game.table.users) do
        self.usersServer[v.seatId]:update(v)
    end
    -- =================解决后台删掉roundInfo的问题====================-
    local dealTime = 0
    -- 更新用户状态
    for k, v in pairs(m_game.table.users) do
        if v.status == 1 then
            self.usersServer[v.seatId]:updateByAction(M.User.ACTIONS.GAME_START)
            dealTime = dealTime + DEAL_TIME
        else
            logd(M.TAG, string.format("==onRoundStart v.status ~= 1 %s", v.user.uid))
        end
    end

    -- 设置庄家
    self:_setDealer()
    -- 发牌
    local dealHandCards = nil
    if data.handCards then
        dealHandCards = array.split(data.handCards,",")
        m_game:addHandCards(dealHandCards)
        self:addCards(dealHandCards)
        -- m_game:setHandCards(array.split(data.handCards, ","))
        -- self.myCards = array.split(data.handCards, ",")
        -- log
        local strLog = "onRoundStart deal Cards : "
        for i=1, #dealHandCards do
            strLog = strLog .. string.format("card%d --> %s, ", i, dealHandCards[i])
        end
        logd(M.TAG, strLog)
    end
    self:_deal(false,dealHandCards)
    -- 当前操作者
    utils.addDelayCall( function()
        if utils.isValid(self.view) then
            self:_setOperate()
        end
    end , dealTime + 1 )
    self:_showCardsType()
    self:_showAllChip()
    self:_nowChip()
    self:hideLoading()
    self:_hideQuickChat()
end

--结算
function M:onRoundEnd(data)
    if self.isGoHomeing then 
        logd(M.TAG,"isGoHomeing")
        return 
    end
    self.roundEndPalying = true
    --结算过程能坐下
    logd(M.TAG, "onRoundEnd +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ START")
    m_game:setRound(m_game.table.round)
    local allChip = m_game:getRound().sumBet
    --更新最新数据
    self:_showAllChip(allChip)
    self:_nowChip(allChip)
    self:_checkSeatBtn()
    local time = m_game:getRound() and m_game:getCountdown(m_game:getRound().nowSeatEndTime) - m_game.table.config.betTime or 0.1
    self.operateUI:hide()
    --self:_showPublicCards()
    self:_showCardsType()
    self:_takeChip(true)
    self:_stopOperate()
    self:_showQuickChat(data)
    self.roundEndTimes = {}
    for k,v in pairs(m_game.table.config.roundEndTimes) do
        self.roundEndTimes[k] =  v / 1000
    end
    
    local resultList = { }
    -- 服务器时间|time1【收筹码】 →time2【亮牌】 →time3【牌型组合 →特殊牌型】* 赢家→ time4【分奖池动画】* 赢家 → time5【输赢结算】 → time6【延迟】| → 客户端 【经验结算】（升级动画）
    local nowTiem = 0
    local isTime1, isTime3, orders, index = true, data.isVs, {}, 0

    --算出有多少人分到了边池
    for i = 1, #data.usersEndInfo do
        if data.usersEndInfo[i].order > 0 then
            table.insert( orders,data.usersEndInfo[i])
            --先保存allBet 到 结算数据里面
            local userDeskInfo = m_game:getDeskInfoByUid(data.usersEndInfo[i].uid)
            data.usersEndInfo[i].allBet = userDeskInfo.allBet
        end
    end
    logd(M.TAG, string.format("得到边池的人有%s人",#orders))
    nowTiem = nowTiem + (isTime1 and self.roundEndTimes.time1 or 0)
    logd(M.TAG, string.format("亮牌---------nowTiem %s---------",nowTiem))
    utils.addDelayCall(function()
        if not utils.isValid(self.view) then return end
        logd(M.TAG, "---------亮牌---------")
        for i = 1, #data.usersEndInfo do
            local user = self.usersServer[data.usersEndInfo[i].seatId]
            user:showCards(data.usersEndInfo[i])
        end
    end , nowTiem)

    nowTiem = nowTiem + (isTime3 and self.roundEndTimes.time2 or 0)
    logd(M.TAG, string.format("玩家结算---------nowTiem %s---------",nowTiem))
    utils.addDelayCall( function()
        if not utils.isValid(self.view) then return end
        local t = 0
        local func
--        if data.isVs then
            func = function()
                    if not utils.isValid(self.view) then return end
                    index = index + 1
                    local info = orders[index]
                    if not info then
                        logd(M.TAG,string.format("has no user to get chip from public pot"))
                        return
                    end
                    local user = self.usersServer[info.seatId]
                    logd(M.TAG,string.format( "用户--> %s 开始进行结算---------",info.uid))
                    dump(info)
                    --从底池中扣除筹码
                    local gainCount =  info.allBet + info.chipCrement 
                    logd(M.TAG, string.format("user uid %s 可以从底池中分到%s筹码 allBet %s chipCrement %s",info.uid,gainCount,info.allBet,info.chipCrement))
                    --如果得到0个筹码则不播放分筹码动画
                    if gainCount and gainCount > 0  then
                        utils.addDelayCall(function ()
                            if not utils.isValid(self.view) then return end
                            allChip = allChip - gainCount
                            self:_showAllChip(allChip)
                            self:_nowChip(allChip)
                             logd(M.TAG, "分奖池动画---------")
                            soundMgr.playEffect(17)
                            for i = 1, 15 do
                                if user.uiStatus == M.User.UI_STATUS.START then
                                    local chip = require("game.modules.game.Chip").new(50000)
                                    self.effect_container:addChild(chip.view)
                                    chip:fly(0.02 * i, cc.p(self.effect_container:convertToNodeSpace(self.allChipPos)), cc.p(self.effect_container:convertToNodeSpace(cc.p(self.users_container:convertToWorldSpace(cc.p(user.view:getPosition()))))))
                                    if i == 15 then
                                        utils.addDelayCall(function() 
                                        user:updateBaseUI() 
                                        end,0.02*i)
                                    end
                                end
                            end
                        end ,isTime3 and self.roundEndTimes.time3 or 0)
                    end
                    t = self.roundEndTimes.time4
                    if isTime3 then
                        logd(M.TAG, "显示牌型（可能包含特殊牌型）---------")
                        self:_compareCard(info)
                        logd(M.TAG, "显示公共牌和用户手牌的组合牌型---------")
                        --self:_showUsePublicCards(info)--很
                    end
                    --如果需要进行牌型组合
                    if isTime3 then t = t + self.roundEndTimes.time3 end
                    if index < #orders then
                        logd(M.TAG, string.format("t-------- %s---------",t))
                        utils.addDelayCall(func,t)           
                    end
              end
        utils.addDelayCall(func,t)
       --end
    end , nowTiem)
    --组合牌型总时间
    local assemblyTime = isTime3 and self.roundEndTimes.time3 * #orders or 0
    --分筹码总时间
    local separateChipTime = self.roundEndTimes.time4 * #orders
    nowTiem =  nowTiem + assemblyTime + separateChipTime
    logd(M.TAG, string.format("输赢结算---------nowTiem %s---------",nowTiem))

    --算出要结算输赢的玩家
    for i = 1, #data.usersEndInfo do
        local user = self.usersServer[data.usersEndInfo[i].seatId]
        user:over(data.usersEndInfo[i])
        if user.uiStatus ==M.User.UI_STATUS.START then
            table.insert(resultList, { user = user, endInfo = data.usersEndInfo[i] })
        else
            logd(M.TAG, string.format("输赢结算---------userPos %s 状态 %s不能结算---------",user.posClient,user.uiStatus))
        end
    end

    utils.addDelayCall(  function()
        if not utils.isValid(self.view) then return end
         -- 清除公牌
        self.cards_container:removeAllChildren()
        -- 清除自己的牌
        self.myCards = { }
        --隐藏底池
        self.all_chip:setVisible(false)
        logd(M.TAG, string.format("---------筹码输赢结算人数 %s---------",#resultList))
        table.sort(resultList, function(a, b)
            if a.endInfo.chipCrement < 1 and b.endInfo.chipCrement > 0 then
                return true
            elseif b.endInfo.chipCrement < 1 and a.endInfo.chipCrement > 0 then
                return false
            else
                return a.user.posClient < b.user.posClient
            end
        end )

        local doResult
        doResult = function()
            if not utils.isValid(self.view) then return end
            if #resultList == 0 then utils.removeDelayCall(doResult) return end
            logd(M.TAG, "筹码输赢结算--------->>>>")
            table.remove(resultList, 1).user:showResult()
        end
        --0.3秒结算一个人
        utils.addDelayCall(doResult, 0.3, 0)
    end , nowTiem)

    nowTiem = nowTiem + self.roundEndTimes.time5 * #resultList + self.roundEndTimes.time6
    logd(M.TAG, string.format("重置状态---------nowTiem %s---------",nowTiem))
    utils.addDelayCall( function()
        if not utils.isValid(self.view) then return end
        logd(M.TAG, "---------重置状态---------")
        logd(M.TAG, "onRoundEnd +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ END")
        self.roundEndPalying = false
        self:_reset()
        m_game:setHandCards(nil)
        self:_showCardsType()
        self:_checkSeatBtn()
        if self.endCallBack then
            self.endCallBack()
            self.endCallBack = nil
        end
    end , nowTiem)

    utils.addDelayCall( function()
        if not utils.isValid(self.view) then return end
        logd(M.TAG, "---------检查升级---------")
        if self.upgradeDelayCall then self.upgradeDelayCall() end
        if m_game.table and m_game.table.status ~= GAME_STATUS.START then
            self:showLoading()
        end
    end , nowTiem)
end

-- 当前操作者
function M:_stopOperate()
    self.light:hide()
    if self.operater then
        self.operater:updateByAction(M.User.ACTIONS.OPERATO_STOP, nil,M.User.ACTIONS.GAME_START)
        self.operater = nil
    end
end

-- 当前操作者
function M:_setOperate()
    local optTime = m_game:getRound() and math.min(m_game.table.config.betTime, m_game:getCountdown(m_game:getRound().nowSeatEndTime)) or m_game.table.config.betTime
    local seatId = m_game:getRound().nowSeatId
    if m_game.table.status ~= GAME_STATUS.START then
        loge(M.TAG, string.format("_setOperate GAME_STATUS %s", m_game.table.status))
        return
    end

    if self.roundEndPalying then return end
    -- 如果游戏结束了
    local isSelf = m_game:isSelfBySeatId(seatId)
    if isSelf then
        winMgr.hideWinLayer()
        cc.UserDefault:getInstance():setBoolForKey("selfOperation",true)
        -- 如果轮到自己操作
    else
        winMgr.showWinLayer()
        cc.UserDefault:getInstance():setBoolForKey("selfOperation",false)
    end
    self:_updateUserBaseUI()
    --    self:_hideQuickChat() --如果出错了强制去掉
    self.operater = self.usersServer[seatId]
    if not self.operater then logd(M.TAG, string.format("_setOperate SeatId: %s is nil", seatId)) return end
    local size = self.users_container:getContentSize()
    local p = cc.p(self.users_container:convertToWorldSpace(self.operater.startPoint))
    p.x = p.x - size.width/2
    p.y = p.y - size.height/2
    utils.addDelayCall( function()
        if utils.isValid(self.view) and self.operater then
            self.light:goto(self.operater.startPoint)
        end
    end , 0.1)

    -- logd(M.TAG, string.format("_setOperate SeatId: %s gameStatus %s optTime %s", seatId, self.operater.uiStatus, optTime))
    -- self.operater:updateByType(User.UPDATE_TYPE.OPERATO_START)
    if self.operater.uiStatus ==M.User.UI_STATUS.START then
        self.operater:updateByAction(M.User.ACTIONS.OPERATO_START, optTime or m_game.table.config.betTime,M.User.ACTIONS.GAME_START)
        if m_game:getSelfDeskInfo() and m_game:getSelfDeskInfo().status == 1 then
            self.operateUI:show(isSelf)
        else
            self.operateUI:hide()
        end
    end
end
 

-- 设置庄家
function M:_setDealer(isStarted)
    self.spr_banker:setVisible(true)
    local pos = self.usersServer[m_game:getRound().dealerSeatId]:getDealerPos()
    if isStarted then
        self.spr_banker:setPosition(pos)
    else
        local action = cc.MoveTo:create(0.5, pos)
        self.spr_banker:runAction(action)
    end
end

-- 发牌
function M:_deal(isStarted,handCards)
    if not handCards then
        return
    end
    local strLog = nil
    if isStarted then
        strLog = "deal card onRoundStart" 
    else
        strLog = "deal card onAction"
    end
    for i=1, #handCards do
        strLog = strLog .. string.format("handCards[%d] --> %s, ", i, handCards[i])
    end
    logd(M.TAG, strLog)
    local function _dea(user, pos1, pos2, info, cards)
        local card = cc.Sprite:create("ui/comm/cards/back.png")
        card:setScale(0.2)
        card:setPosition(pos1)
        local act1 = cc.Spawn:create(cc.MoveTo:create(0.2, pos2), cc.ScaleTo:create(0.2, 0.5))
        local act2 = cc.CallFunc:create( function() card:removeFromParent() user:addCard(info, cards) end)
        local action = cc.Sequence:create(act1, act2)
        card:runAction(action)
        self.view:addChild(card,13)
    end

    local index = 1
    local round = 1

    local getNextUser
    getNextUser = function()
        if round == 0 then return nil end
        local user = self.usersServer[index]
        index = index + 1
        if index > #self.usersServer then
            index = 1
            round = round - 1
        end
        --user.info 原则上不在这里进行访问，后面改
--        if user and user.uiStatus == M.User.UI_STATUS.START and user.info and user.info.status == 1 then
        if user and user:needCard() then
            return user
        else
            logd(M.TAG,string.format("==user %s cannot deal ui_status : %s",user.posClient,user.uiStatus))
            return getNextUser()
        end
    end

    local function f3()
        if not tolua.cast(self.view, "cc.Node") or round == 0 then
            
            utils.removeDelayCall(f3)
            return
        end

        local user = getNextUser()
        if user then
            -- 三公玩法，三张手牌一次性发牌到位
            --[[removed by philzhou            
            _dea(user,
                self.cardStartPos,
                user:getCardPos(),
                (round == 2 and { Card.BACK, nil } or { Card.BACK, Card.BACK }),
                (user:isSelf() and round ~= 2) and self.myCards or nil)
            --]]
            
            local seqCards = {}
            local loopNum = #handCards
            -- if self.myCards~=nil then
            --     loopNum = #self.myCards
            -- end
            for i=1, loopNum do
                table.insert(seqCards, Card.BACK)
            end
            _dea(user,
                self.cardStartPos,
                user:getCardPos(),
                seqCards,
                (user:isSelf()) and handCards or nil)

        end
    end

    function f4()
        for i = 1, #self.usersServer do
            local user = getNextUser()
            if user and user:needCard() then
                if user:isSelf() then
                    user:addCard(self.myCards, self.myCards, true)
                else
                    local seqCards = {}
                    local loopNum = 0
                    if self.myCards~=nil then
                        loopNum = #self.myCards
                    end
                    for i=1, loopNum do
                        table.insert(seqCards, Card.BACK)
                    end
                    user:addCard( seqCards )
                end
            end
        end
    end

    if isStarted then
        f4()
    else
        soundMgr.playEffect(13)
        utils.addDelayCall(f3, DEAL_TIME / 2, 0)
    end
end

-- 用户位移动画
function M:_convertUserPos(cb)
    --dump(self.usersClient,"self.usersClient",2)
    local selfSeatId = self:_getSelfSeatId()
    logd(M.TAG,string.format("_convertUserPos_ selfSeatId %s",selfSeatId))
    if selfSeatId then
        local x =((self.myPosIndex + 1) - selfSeatId + self.maxUser) % self.maxUser
        if (x == 0) then x = self.maxUser end
        self.usersServer = utils.table.convertIndex(self.usersClient, x)
    else
        self.usersServer = {}
        for i = 1 , #self.usersClient do
            self.usersServer[i] = self.usersClient[i]
        end
--        self.usersServer = utils.table.copy(self.usersClient)
    end
    --dump(self.usersServer,"self.usersServer",2)

end

-- 游戏开始了
function M:onAction(data)
    local actionData = data.action
    local seatId = actionData.seatId
    local uid = actionData.uid
    local action = actionData.action
    local isSelf =(uid == m_game.user.uid)
    logd(M.TAG, string.format("======= onAction : [%s] user %s isSelf: %s=======",action,uid, tostring(isSelf)))
    if self.isGoHomeing then 
        logd(M.TAG,"isGoHomeing")
        return 
    end
    if action == USER_ACTION.ADD_CARD then
        local dealHandCards = array.split(data.handCards,",")
        m_game:addHandCards(dealHandCards)
        self:_deal(false,dealHandCards)
        self:_setOperate()
    elseif action == USER_ACTION.GAME_CALL then
        self.usersServer[seatId]:updateByAction(M.User.ACTIONS.CALL, nil,M.User.ACTIONS.GAME_START)
        self:_setOperate()
        soundMgr.playEffect(m_game:getUserInfoByUid(uid).gender == 1 and 107 or 7)
    elseif action == USER_ACTION.GAME_CHECK then
        self.usersServer[seatId]:updateByAction(M.User.ACTIONS.CHECK, nil,M.User.ACTIONS.GAME_START)
        self:_setOperate()
        soundMgr.playEffect(m_game:getUserInfoByUid(uid).gender == 1 and 108 or 8)
    elseif action == USER_ACTION.GAME_FOLD then
        if isSelf then self.quickChatData.isFold = true end
        self.usersServer[seatId]:updateByAction(M.User.ACTIONS.FOLD, nil,M.User.ACTIONS.GAME_READY)
        self:_setOperate()
        soundMgr.playEffect(m_game:getUserInfoByUid(uid).gender == 1 and 109 or 9)
    elseif action == USER_ACTION.GAME_RAISE then
        self.usersServer[seatId]:updateByAction(M.User.ACTIONS.RAISE, nil,M.User.ACTIONS.GAME_START)
        self:_setOperate()
        soundMgr.playEffect(m_game:getUserInfoByUid(uid).gender == 1 and 112 or 12)
    elseif action == USER_ACTION.GAME_ALLIN then
        self.usersServer[seatId]:updateByAction(M.User.ACTIONS.ALLIN, nil,M.User.ACTIONS.GAME_START)
        self:_setOperate()
        soundMgr.playEffect(10)
        soundMgr.playEffect(m_game:getUserInfoByUid(uid).gender == 1 and 111 or 11)
    elseif action == USER_ACTION.SYS_FLOP1 or action == USER_ACTION.SYS_FLOP2 or action == USER_ACTION.SYS_FLOP3 then
        self:_roundOver(action == USER_ACTION.SYS_FLOP1 and 14 or 15 )
    elseif action == USER_ACTION.SYS_REBUY then
        if isSelf then
            --utils.addDelayCall( function() winMgr.tips( { txt = string.format(gameTxt.AutoBuyin, utils.format(actionData.actionData.count, 1)) }) end, 2)
        end
        return
    elseif action == USER_ACTION.SYS_SITDOWN then
        self:_seatDown(seatId, isSelf)
    elseif action == USER_ACTION.SYS_STANDUP then
        if isSelf and self.isChangeDesking then return end
        -- 如果用户换桌中则不站起自己
        self:_seatUp(seatId, isSelf)
    elseif action == USER_ACTION.SYS_LEAVE then
        self:_leave()
    end
    self:_showAllChip()
end

function M:_showCardsType(isMark)
    local myIs_seatDown = m_game:getSelfDeskInfo()
    local cardsType = m_game:getCardsType()
    logd(M.TAG,string.format("show my cardsType is:%s",cardsType and cardsType.name or "null"))
    dump(cardsType)
    local isVisible = cardsType and(m_game.table.status == GAME_STATUS.START or self.roundEndPalying) and myIs_seatDown ~= nil and cardsType ~= nil
    if self.btn_cards_type and cardsType then
        self.btn_cards_type:setVisible(isVisible)
        if cardsType.type == 1 then
            -- 高牌，显示点数
            self.btn_cards_type:setTitleText(tostring(math.floor(cardsType.index/1000)).." Points")
        else
            -- 非高牌，直接显示名称
            self.btn_cards_type:setTitleText(cardsType.name)
        end
    end
    if not isVisible then 
        if self.btn_cards_type then
            self.btn_cards_type:setVisible(isVisible)
        end
        return 
    end
    
    ---标记出具体的牌
    local publicCards = self.cards_container:getChildren()

 
    if not utils.isValid(self.view) then return end
    if isMark then
        for i = 1, #publicCards do
            local c = publicCards[i]
            if utils.isValid(c) then
                c.owner:mark()
            end
        end
    end
    local user = self:_getUserByUid(m_game.user.uid)
    if user then
        user:markCards()
    end
end

function M:_roundOver(soundId)
    local time = m_game:getRound() and m_game:getCountdown(m_game:getRound().nowSeatEndTime) - m_game.table.config.betTime or 0.5
    self:_stopOperate()
    self:_takeChip()
    self.operateUI:hide()
    performWithDelay(self.view, function() self:_showPublicCards() soundMgr.playEffect(soundId) end, 2.5)
    performWithDelay(self.view, function() self:_setOperate() end, time)
end

function M:_updateUserBaseUI()
    if not utils.isValid(self.cards_container) then return end
    for i = 1, #self.usersServer do
        self.usersServer[i]:updateBaseUI()
    end
end

--显示单轮底池
function M:_nowChip(chip)
    if not utils.isValid(self.cards_container) then return end
    self.allChip = 0
    if not m_game:getRound() then self.all_chip:setVisible(false) return end
    --结算时候的筹码
    if chip then self.all_chip:getChildByName("lab_now_chips"):setString(utils.format(chip, 1)) return end
    --结算过程中不刷新后台的实际数据
    if self.roundEndPalying then return end
    -- 用户站起可能会删掉round
    for k, v in pairs(m_game:getRound().pots) do
        self.allChip = self.allChip + v.all
    end
    self.all_chip:getChildByName("lab_now_chips"):setString(utils.format(self.allChip, 1))
end

--显示总底池
function M:_showAllChip(chip)
    if not m_game:getRound() or not utils.isValid(self.cards_container) then return end
    --结算时候的筹码
--    if chip then self.all_chip:getChildByName("lab_all_chips"):setString("POT " .. utils.format(chip, 1)) return end
    if chip then
        self:_showTableInfo(chip)
        return
    end
    --结算过程中不刷新后台的实际数据
    if self.roundEndPalying then return end
    self.all_chip:setVisible(m_game:getRound().sumBet > 0)
    self:_showTableInfo()
    --self.all_chip:getChildByName("lab_all_chips"):setString("POT " .. utils.format(m_game:getRound().sum  rtrtthjnikjBet, 1))
end

function M:_showTableInfo(chip)
    local sumBet = m_game:getRound() and m_game:getRound().sumBet or 0
    self.lab_table_info:setString(string.format("%s %s/%s POT:%s", getRootTitle(m_game.table.config.minBet), utils.format(m_game.table.config.minBet, 1), utils.format(m_game.table.config.minBet * 2, 1),utils.format(chip or sumBet, 1)))
end

function M:_showUsePublicCards(info)
    logd(M.TAG, string.format("_showUsePublicCards----------"))
    if not m_game:getRound() then return end
    local card
    local endCards = info.scoreCards
    local cards = array.split(m_game:getRound().commCards, ",")
    if not endCards or not cards then return end
    local publicCards = self.cards_container:getChildren()

    local list = {}
    for i = 1, #publicCards do
        table.insert(list,publicCards[i].owner )
    end
    for i = 1 ,#list do
        list[i]:markUp(endCards)
    end
end

function M:_showPublicCards(isStarted)
    local isDeprecated = true
    if isDeprecated then
        return
    end
    local cards = array.split(m_game:getRound().commCards, ",")
    -- logd(M.TAG, "_showPublicCards")
    local startX = -179
    local startY = 10
    local gap = 30
    local size
    local card
    local function f()
        local cardList = {}
        if #cards == 0 or self.publicCardCount == #cards or not tolua.cast(self.view, "cc.Node") then
            utils.removeDelayCall(f)
            return
        end
        self.publicCardCount = self.publicCardCount + 1
        if not cards[self.publicCardCount] then
            utils.removeDelayCall(f)
            logd(M.TAG, string.format("===============showPublicCards ERROR====================="))
            loge(M.TAG, string.format("m_game:getRound().commCards %s self.publicCardCount %s", m_game:getRound().commCards, self.publicCardCount))
            logd(M.TAG, string.format("===============showPublicCards ERROR====================="))
            return
        end
        --card = cc.Sprite:create("ui/comm/cards/" .. cards[self.publicCardCount] .. ".png")
        card = Card.new()
        table.insert(cardList,card)
        card.view:setScale(0.3)
        size = card.view:getContentSize()
        card.view:setPosition(self.cards_container:convertToNodeSpace(self.cardStartPos))
        card.view:setTag(cards[self.publicCardCount])
        self.cards_container:addChild(card.view)
        card.reverseData = cards[self.publicCardCount]

        local act1 = cc.Spawn:create(cc.MoveTo:create(0.2, cc.p(startX +((self.publicCardCount - 1) *(gap + size.width)), startY)), cc.ScaleTo:create(0.2, CARD_SCALE))
        local act2 = cc.Sequence:create(cc.DelayTime:create(self.publicCardCount*0.04), cc.CallFunc:create( function() 
            if #cardList > 0 then
                local card = table.remove(cardList,1)
                card:reverse(card.reverseData) 
            end
         end))
        local action = cc.Sequence:create(act1, act2)

        if isStarted then
            card.view:setScale(CARD_SCALE)
            card.view:setPosition(cc.p(startX +((self.publicCardCount - 1) *(gap + size.width)), startY))
            card:setData(cards[self.publicCardCount])
        else
            card.view:runAction(action)
        end
    end

    if isStarted then
        for i = 1, #cards do f() end
    else
        utils.addDelayCall(f,0.02, 0)
    end
    self:_showCardsType(true)
end

function M:_takeChip(isOver)
    -- logd(M.TAG, string.format("---_takeChip---"))

    local pots = clone(m_game:getRound().pots)
    function f()
        for i = 1, #self.usersServer do
            -- 收筹码
            self.usersServer[i]:allChipTo(self.allChipPos, function(add) end)
        end
        self:_nowChip()
    end
    if isOver then
        performWithDelay(self.view, f, 0.5)
    else
        performWithDelay(self.view, f, 1)
    end
end

function M:_reset()
    m_game:setRound(nil)
    if not tolua.cast(self.view, "cc.Node") then return end
    logd(M.TAG, "------------TABLE RESET------------")
    -- 清除公牌
    self.cards_container:removeAllChildren()
    
    self.myCards = { }
    self.convertCount = 0
    self.all_chip:setVisible(false)
    self.spr_banker:setVisible(false)
    self.allChip = 0
    -- 公共牌数量
    self.publicCardCount = 0
    
    self.operater = nil
    self.operateUI:hide()

    for i = 1, #self.usersClient do
        self.usersClient[i]:reset()
    end

    self:_checkSeatBtn()
    -- 被隐藏的窗口打开
    winMgr.showWinLayer()
end

function M:_getSelfSeatId()
    for i = 1, self.maxUser do
        -- 得到偏移值
        if m_game.table.users["seat" .. i] then
            if m_game.table.users["seat" .. i] and m_game.table.users["seat" .. i].user.uid == m_game.user.uid then
                return i
            end
        end
    end
end
function M:upgrade()
    self.upgradeDelayCall = function()
        local user = self:_getUserByUid(m_game.user.uid)
        if user then
            user:upgrade()
        end
        self.upgradeDelayCall = nil
    end
end

function M:chat(data)
    local user = self:_getUserByUid(data.uid)
    assert(user, string.format("user chat can't find this user ->%s", data.uid))
    user:chat(data)
end

function M:interact(data)
    -- logd(M.TAG, string.format("收到了互动的广播 : form %s to %s type %s data %s", data.fromSeatId, data.toSeatId, data.type, data.data))
    local fromUser, toUser = self:_getUserByUid(data.fromUid), self:_getUserByUid(data.toUid)
    assert(fromUser and toUser, string.format("interact chat can't find this fromUser ->%s toUser -> %s", data.fromUid, data.toUid))
    local eff = Interact.new(data.data):run(cc.p(fromUser.view:getPosition()), cc.p(toUser.view:getPosition()))
    self.users_container:addChild(eff, 999999)
end

function M:_setConvertUserRun(isRun)
    if isRun then
        self.light:hide()
    elseif self.operater then
        self.light:goto(cc.p(self.operater.view:getPosition()))
    end
    --    self.btn_chat:setTouchEnabled(not isRun)
    --    self.btn_menu:setTouchEnabled(not isRun)
end

-- 比牌
function M:_compareCard(info)
    dump(info)
    local user = self.usersServer[info.seatId]
    user:compareCards(info)
    local oldZOrder,oldZOrder1,oldZOrder2 = user.view:getLocalZOrder(),self.cards_container:getLocalZOrder(),self.effect_container:getLocalZOrder()
    
    if not self.users_container:getChildByName("maskLayer") then
        local maskLayer = cc.LayerColor:create(cc.c4b(0x00, 0x00, 0x00, 0x88), display.width, display.height)
        :setName("maskLayer")
        :setLocalZOrder(9998)
        self.users_container:addChild(maskLayer)
    else
        self.users_container:getChildByName("maskLayer"):setVisible(true)
    end
    user.view:setLocalZOrder(9999)
    self.cards_container:setLocalZOrder(self.users_container:getLocalZOrder() + 1)
--    self.effect_container:setLocalZOrder(self.users_container:getLocalZOrder() + 2)
    local callback = function ()
        self.users_container:getChildByName("maskLayer"):setVisible(false)
--        self.effect_container:setLocalZOrder(oldZOrder2)
        self.cards_container:setLocalZOrder(oldZOrder1)
        user.view:setLocalZOrder(oldZOrder)
    end

    require("game.modules.game.UserCardType").new(user, info.scoreType ,callback)
--    info.scoreType = 9
    -- if true then
    if info.scoreType > 6 then
        logd(M.TAG, string.format("**********显示特殊牌型（%s）**********", info.scoreType))
        local spr = require("game.modules.game.SpecialType").new(info.scoreType ,  0.7)
        spr:setPosition(cc.p(0, 60))
        self.effect_container:addChild(spr)
    end
    logd(M.TAG, string.format("显示牌型结束-----------------", info.scoreType))
end

-- 根据用户uid得到用户
function M:_getUserByUid(uid)
    for i = 1, #self.usersServer do
        if self.usersServer[i].info and self.usersServer[i].info.user.uid == uid then
            return self.usersServer[i]
        end
    end
end

-- 解决后台换桌的时候先站起玩家的问题
function M:changeDesking()
    self.isChangeDesking = true
end 

function M:_showQuickChat(data)
    local type = 0
    local winerCount = 0
    local needShow = false

    for i = 1, #data.usersEndInfo do
        if data.usersEndInfo[i].chipCrement > -1 then
            winerCount = winerCount + 1
        end
        if m_game:isSelfByUid(data.usersEndInfo[i].uid) then
            needShow = true
        end
    end
    if not needShow then
        self.quickChatData.winCount = nil
        return
    end
    for i = 1, #data.usersEndInfo do
        local userEnd = data.usersEndInfo[i]
        if m_game:isSelfBySeatId(userEnd.seatId) and userEnd.chipCrement > 0 then
            type =(winerCount == 1 and 2) or(data.isVs and 3 or type)
            -- 只有玩家一人未弃牌 2--	摊牌后玩家胜利 3
            if self.quickChatData.winCount then
                self.quickChatData.winCount = self.quickChatData.winCount + 1
                if self.quickChatData.winCount == 3 then
                    -- 连赢3次以上 1
                    self.quickChatData.winCount = nil
                    type = 1
                end
            else
                self.quickChatData.winCount = 1
            end
            break
        elseif data.isVs and m_game:isSelfBySeatId(userEnd.seatId) and userEnd.chipCrement < 0 then
            -- 摊牌后玩家失败 4
            type = 4
            self.quickChatData.winCount = nil
            break
        elseif self.quickChatData.isFold then
            self.quickChatData.isFold = nil
            self.quickChatData.winCount = nil
            -- 玩家弃牌
            type = 5
        end
    end
    if type > 0 and m_game:getSelfDeskInfo() then
        self.quickChatUI = QuicChat.new(type)
        self.view:addChild(self.quickChatUI,10)
    end
end

function M:_hideQuickChat()
    if utils.isValid(self.quickChatUI) then self.quickChatUI:removeFromParent() end
end

function M:onDeskUserInfoChange()
    for k, v in pairs(m_game.table.users) do
        self.usersServer[v.seatId]:setGiftIcon()
    end
end

function M:showLoading(data, class, isMask)
    self:hideLoading()
    self.loading = require("game.modules.game.Waiting").new()
    self.view:addChild(self.loading,11)
    self.loading:show(data)
end

function M:hideLoading()
    if self.loading then
        self.loading:removeFromParent()
        self.loading = nil
    end
end
--离开
function M:_leave()
end

--返回大厅中
function M:onGoHome()
    self.isGoHomeing = true
end

function M:_playAnim()
    if not self.girlAction then
        self.girlActions = { "zhayan", "dianzhuo" }
        self.girlAction = cc.CSLoader:createTimeline("effect/girl/01dz_hg.csb")
        self.view:getChildByName("woman"):runAction(self.girlAction)
    end
    local play
    play = function()
        if utils.isValid(self.view) then
            self.girlAction:play(self.girlActions[math.random(3)], false)
            utils.addDelayCall(play, math.random(2) + 2)
        end
    end
    play()
end

return M
