-- SlamFrames v0.11 custom bar engine.
-- Width/texture-coordinate based fill for reliable old-client rendering.

SlamFrames_BarEngine = SlamFrames_BarEngine or {}
local B = SlamFrames_BarEngine

B.active = B.active or {}
B.speed = 10

local updater = CreateFrame("Frame", "SlamFrames_BarUpdater", UIParent)
updater:SetScript("OnUpdate", function()
    local elapsed = arg1 or 0
    local bar
    for bar in pairs(B.active) do
        if not bar.smooth or bar.displayValue == bar.value then
            bar.displayValue = bar.value
            bar:UpdateVisual()
            B.active[bar] = nil
        else
            local delta = bar.value - bar.displayValue
            local step = math.min(1, elapsed * B.speed)
            bar.displayValue = bar.displayValue + delta * step
            if math.abs(bar.value - bar.displayValue) < 0.05 then
                bar.displayValue = bar.value
                B.active[bar] = nil
            end
            bar:UpdateVisual()
        end
    end
end)

function B:Create(parent, rect, texturePath, textureFile)
    local bar = CreateFrame("Frame", nil, parent)
    bar.baseRect = rect
    bar.max = 100
    bar.value = 100
    bar.displayValue = 100
    bar.smooth = true

    bar.fill = bar:CreateTexture(nil, "OVERLAY")
    bar.fill:SetTexture(texturePath .. textureFile)
    bar.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.fill:SetTexCoord(0, 1, 0, 1)
    bar.fill:SetAlpha(1)

    function bar:SetLayout(scale, widthTrim)
        local r = self.baseRect
        scale = scale or 1
        widthTrim = math.max(0, widthTrim or 0)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT", r.x * scale, r.y * scale)
        self:SetWidth(math.max(20, r.w - widthTrim) * scale)
        self:SetHeight(r.h * scale)
        self.fullWidth = math.max(20, r.w - widthTrim) * scale
        self.fullHeight = r.h * scale
        self:Show()
        self.fill:ClearAllPoints()
        self.fill:SetPoint("LEFT", self, "LEFT", 0, 0)
        self.fill:SetHeight(self.fullHeight)
        self:UpdateVisual()
    end

    function bar:UpdateVisual()
        local pct = 0
        if self.max and self.max > 0 then pct = self.displayValue / self.max end
        if pct < 0 then pct = 0 end
        if pct > 1 then pct = 1 end
        if pct <= 0.001 then
            self.fill:Hide()
            return
        end
        self:Show()
        self.fill:Show()
        self.fill:SetAlpha(1)
        self.fill:SetHeight(self.fullHeight or self:GetHeight())
        self.fill:SetWidth(math.max(0.5, (self.fullWidth or self:GetWidth()) * pct))
        self.fill:SetTexCoord(0, pct, 0, 1)
    end

    function bar:SetValue(cur, maxv, instant)
        maxv = maxv or 1
        if maxv <= 0 then maxv = 1 end
        cur = cur or 0
        if cur < 0 then cur = 0 end
        if cur > maxv then cur = maxv end
        self.max = maxv
        self.value = cur
        if instant or not self.smooth then
            self.displayValue = cur
            B.active[self] = nil
            self:UpdateVisual()
        else
            if self.displayValue == nil then self.displayValue = cur end
            B.active[self] = true
        end
    end

    function bar:SetFillColor(r, g, b, a)
        self.fill:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end

    function bar:SetSmooth(enabled)
        self.smooth = enabled and true or false
        if not self.smooth then
            self.displayValue = self.value
            B.active[self] = nil
            self:UpdateVisual()
        end
    end

    bar:SetLayout(1)
    return bar
end
