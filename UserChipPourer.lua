local M = class("UserChipPourer")
M.TAG = "UserChipPourer"
local chipOriginalPosition = {x = 0,y = 0}
local ADD_CHIP_EFFECT_ID = 5
function M:ctor( pourNode )
    self.pour_node = pourNode
    self.img_banker = pourNode:getChildByName("img_banker")
    self.chip_container = pourNode:getChildByName("pour_chip_container")
    self.node_pour_num = pourNode:getChildByName("node_pour_num")
    self.txt_pour_chip = self.node_pour_num:getChildByName("txt_pour_chip")
end
function M:payChip( isStart,betNum,needRecyle )
    logd(M.TAG,string.format("user pay chip:%s,isStart:%s",betNum,isStart))
    if betNum == 0 then
        return
    end
    self.txt_pour_chip:setString(utils.format(betNum,1))
    self:showPourNum()
    if needRecyle then
        self:recyleChips(function (  )
            self:addChip(betNum, not isStart)
        end)
    else
        self:addChip(betNum,not isStart)
    end
end
function M:addChip( betNum,animated )
    soundMgr.playEffect(ADD_CHIP_EFFECT_ID)
    local chipValues = self:betNum2ChipValues(betNum)
    local chipPileNode = cc.Node:create()
    local chipEndPosition = self.chip_container:getPosition()
    if animated then
        for i=1,#chipValues do
            local chip = Chip.new(chipValues[i])
            local chipFinalPosition = { x = chipEndPosition.x + math.random(-3,3),
                                        y = chipEndPosition.y + 4*i - 2}
            chip.view:setPosition(chipFinalPosition)
            chipPileNode:addChild(chip.view)           
        end
    else
        for i=1,#chipValues do
            local chip = Chip.new(chipValues[i])
            local chipStartPosition = {
                x = chipOriginalPosition.x + math.random(-3,3)
                y = chipOriginalPosition.y + (i - 1) * 2
            }
            local chipFinalPosition = {
                x = chipEndPosition.x + math.random(-3,3)
                y = chipEndPosition.y + (i - 2) * 2
            }
            chip.view:setPosition(chipStartPosition)
            chip:moveTo(chipFinalPosition)
            chipPileNode:addChild(chip.view)
        end
    end
    self.chip_container:addChild(chipPileNode)
end
function M:betNum2ChipValues( betNum )
    local chipValues = {}
    local maxChipNum = 5
    local index = 1
    while betNum > 0 and #chipValues < maxChipNum do
        if CHIP_VALUE[index] > betNum then
            betNum = betNum - (CHIP_VALUE[index -1] or CHIP_VALUE[1])
            table.insert(chipValues,CHIP_VALUE[index -1])
            index = 1
        else
            index = index + 1
        end
    end
    return chipValues
end
function M:allChipToPool()
    logd(M.TAG,"user put all chip to pool")
    self:hidePourNum()
    local allChips = {}
    local chipPiles = self.chip_container:getChildren()
    for i=1,#chipPiles do
        local chips = chipPiles[i]:getChildren()
        utils.table.push(allChips)
    end
    for i=1,#allChips do
        allChips[i]:captureTo(poolChipPosition,nil,0.05*(i-1))
    end
end
function M:recyleChips( callback )
    logd(M.TAG,"user do recyle chip")
    local allChips = {}
    local chipPiles = self.chip_container:getChildren()
    local chipPileCount = #chipPiles
    if chipPileCount == 0 then
        if callback then
            callback()
        end
        return
    end
    for i=1,chipPileCount do
        local chips = chipPiles[i]:getChildren()
        utils.table.push(allChips,chips)
    end
    for i=1,#allChips do
        allChips[i].owner:backTo(chipOriginalPosition,i == 1 and callback or nil)
    end
end
function M:showPourNum(  )
    self.node_pour_num:setVisible(true)
end
function M:hidePourNum(  )
    self.node_pour_num:setVisible(false)
end
function M:hideBanker(  )
    self.img_banker:setVisible(false)
end
function M:showBanker(  )
    self.img_banker:setVisible(true)
end
return M