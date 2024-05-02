local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0");

---@class (exact) LibForecast-1.0
---@field public WeatherType LibForecast1.WeatherType
---@field private frame Frame
---@field private callbacks CallbackHandlerRegistry
---@field private weatherInfo LibForecast1.WeatherInfo
local LibForecast = LibStub:NewLibrary("LibForecast-1.0", 3);

if not LibForecast then
    return;
end

---@class LibForecast1.WeatherType
LibForecast.WeatherType = {
    Clear = 1,
    Rain = 2,
    Snow = 3,
    Sandstorm = 4,
    Miscellaneous = 5,
    Unknown = -1,
};

---@return LibForecast1.WeatherInfo
function LibForecast:GetCurrentWeatherInfo()
    local shallow = true;
    return CopyTable(self.weatherInfo, shallow);
end

local DefaultWeatherInfo = {
    type = LibForecast.WeatherType.Unknown,
    intensity = 0,
};

---@param weatherType integer
---@param intensity number
---@return LibForecast1.WeatherInfo
local function CreateWeatherInfo(weatherType, intensity, recordID)
    return {
        type = weatherType,
        intensity = intensity,
        recordID = recordID,
    }
end

---@private
function LibForecast:OnLoad()
    if not self.frame then
        self.frame = CreateFrame("Frame");
    end

    if not self.callbacks then
        self.callbacks = CallbackHandler:New(self);
    end

    if not self.weatherInfo then
        self:SetCurrentWeatherInfo(DefaultWeatherInfo);
    end

    self.frame:RegisterEvent("ADDONS_UNLOADING");
    self.frame:RegisterEvent("CONSOLE_MESSAGE");
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
    self.frame:SetScript("OnEvent", function(_, ...) self:OnEvent(...); end);
end

---@return LibForecast1.WeatherInfo
local function ParseWeatherChangedMessage(message)
    -- Console messages are always English strings, so no localization
    -- concerns. We do however have an itty bitty problem in that there's
    -- two messages with varying levels of information.

    local weatherType, intensity, recordID;
    local weatherInfo;

    if string.find(message, "Weather changed to") == 1 then
        weatherType = tonumber(string.match(message, "changed to (%d+)"));
        intensity = tonumber(string.match(message, "intensity ([%d.]+)"));
        recordID = tonumber(string.match(message, "recID (%d+)"));

        if not weatherType then
            weatherType = LibForecast.WeatherType.Unknown;
        end

        if not intensity then
            intensity = 0;
        end

        weatherInfo = CreateWeatherInfo(weatherType, intensity, recordID);
    end

    return weatherInfo;
end

---@private
function LibForecast:OnEvent(event, ...)
    if event == "CONSOLE_MESSAGE" then
        local weatherInfo = ParseWeatherChangedMessage((...));

        if weatherInfo then
            self:SetCurrentWeatherInfo(weatherInfo);
        end
    elseif event == "ADDONS_UNLOADING" then
        self:SaveVolatileState();
    elseif event == "PLAYER_ENTERING_WORLD" then
        local _, isReloadingUi = ...;

        if isReloadingUi then
            self:LoadVolatileState();
        end
    end
end

---@param old LibForecast1.WeatherInfo
---@param new LibForecast1.WeatherInfo
local function HasWeatherChanged(old, new)
    if (old and not new) or (new and not old) then
        return true;
    elseif old.type ~= new.type then
        return true;
    elseif old.intensity ~= new.intensity then
        return true;
    else
        return false;
    end
end

---@private
---@param weatherInfo LibForecast1.WeatherInfo
function LibForecast:SetCurrentWeatherInfo(weatherInfo)
    local oldWeatherInfo = self.weatherInfo;

    if not HasWeatherChanged(oldWeatherInfo, weatherInfo) then
        return;
    end

    self.weatherInfo = weatherInfo;

    local shallow = true;
    weatherInfo = CopyTable(weatherInfo, shallow);
    self.callbacks:Fire("OnWeatherChanged", weatherInfo.type, weatherInfo);
end

---@private
function LibForecast:LoadVolatileState()
    local serialized = C_CVar.GetCVar("LibForecast1_VolatileState") or "";
    local weatherType, intensity, recordID = string.split(":", serialized);

    weatherType = tonumber(weatherType);
    intensity = tonumber(intensity);
    recordID = tonumber(recordID);

    if weatherType then
        local weatherInfo = CreateWeatherInfo(weatherType, intensity, recordID);
        self:SetCurrentWeatherInfo(weatherInfo);
    end
end

---@private
function LibForecast:SaveVolatileState()
    local weatherInfo = self.weatherInfo;
    local weatherType = tostring(weatherInfo.type);
    local intensity = tostring(weatherInfo.intensity);
    local recordID = tostring(weatherInfo.recordID or "");

    local serialized = string.join(":", weatherType, intensity, recordID);

    C_CVar.RegisterCVar("LibForecast1_VolatileState", "");
    C_CVar.SetCVar("LibForecast1_VolatileState", serialized);
end

LibForecast:OnLoad();

---@class (exact) LibForecast1.WeatherInfo
---@field type LibForecast1.WeatherType
---@field intensity number
---@field recordID integer?

if (...) == "LibForecast" then
    local function OnSlashCommand()
        DevTools_Dump({ weatherInfo = LibForecast:GetCurrentWeatherInfo() });
    end

    local function OnWeatherChanged(_, _, weatherInfo)
        DevTools_Dump({ event = "CHANGE", weatherInfo = weatherInfo });
    end

    LibForecast.RegisterCallback({}, "OnWeatherChanged", OnWeatherChanged);
    SlashCmdList["FORECAST"] = OnSlashCommand;
    SLASH_FORECAST1 = "/forecast";
end
