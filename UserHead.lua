local M = class("UserHead")
local userIcon = require "game.modules.global.UserIcon"
function M:ctor( container )
    self.head_container = container
    self.head = container:getChildByName("head")
    self.headScale = container:getScale()
    self.progress_container = self.head:getChildByName("progress_container")
    self.img_head_container = self.head:getChildByName("img_head_container")
    self.img_head = self.img_head_container:getChildByName("img_head")
    self.img_head:retain()
    self.img_head:removeFromParent()
    local mask = cc.Sprite:create("ui/game/game_user/mask.png")
    local clipNode = cc.ClippingNode:create()
    clipNode:setInverted(false)
    clipNode:setAlphaThreshold(0)
    clipNode:addChild(self.img_head)
    clipNode:setStencil(mask)
    self.img_head_container:addChild(clipNode,0)
    self.img_head:release()
    
    self.head:getChildByName("spr_2"):setVisible(false)
    self.head:getChildByName("img_name_bg"):setVisible(false)
    self.img_head:setCascadeOpacityEnabled(true)    
end
function M:showOperateProgress( betDuration,remainDuration )
    local fromPercentage = (remainDuration/betDuration)*100
    local progress_bar_copy = self.head:getChildByName("spr_2")
    local progress_bar_size = progress_bar_copy:getContentSize()
    if not self.head.progressBar then    
        local position = cc.p(progress_bar_copy:getPosition())
        local progressSprite = cc.Sprite:createWithTexture(progress_bar_copy:getTexture())
        progressSprite:setVisible(true)
        progressSprite:setFlippedX(true)
        self.progressBar = cc.ProgressTimer:create(progressSprite)
        self.progressBar:setType(cc.PROGRESS_TIMER_TYPE_RADIAL)
        self.progressBar:setPosition(position)
        self.progress_container:addChild(self.progressBar)
    end
    self.progressBar:stopAllActions()
    local toPercentageAction = cc.ProgressFromTo:create(remainDuration, fromPercentage, 0)
    local endAction = cc.CallFunc:create( function()
        local draw = cc.DrawNode:create()
        self.progress_container:addChild(draw, 0)
        draw:drawSolidCircle(cc.p(2 - 1, progress_bar_size.width / 2 - 1), 4, math.pi / 2, 4, 1.0, 1.0, cc.c4f(1, 0, 0, 1))
        draw:runAction(cc.RepeatForever:create(cc.Sequence:create(cc.DelayTime:create(0.5), cc.CallFunc:create( function()
            draw:setVisible(not draw:isVisible())
        end ))))
    end )
    self.head.progressBar:setVisible(true)
    self.head.progressBar:runAction(cc.Sequence:create(toPercentageAction, endAction))
    utils.display.G2R(self.head.progressBar, betDuration, remainDuration)    
end
function M:isOperating(  )
    return self.progressBar ~= nil
end
function M:hideOperateProgress(  )
    self.progress_container:removeAllChildrend()
    self.progressBar = nil
end
function M:show(  )
    self.head:setVisible(true)
end
function M:hide(  )
    self.head:setVisible(false)
end
function M:loadIcon( iconName )
    userIcon.loadIcon(self.img_head, info.user.icon)   
end
function M:toDark(  )
    --self.head:setColor(cc.c3b(150, 150, 150))
    self.img_head:setColor(cc.c3b(150, 150, 150))
end
function M:toUnDark()
    --self.head:setColor(cc.c3b(255, 255, 255))
    self.img_head:setColor(cc.c3b(255, 255, 255))
end
return M