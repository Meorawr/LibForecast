local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0");
local LibForecast = LibStub:NewLibrary("LibForecast-1.0", 1);

if not LibForecast then
    return;
end

if not LibForecast.callbacks then
    LibForecast.callbacks = CallbackHandler:New(LibForecast);
end

if not LibForecast.frame then
    LibForecast.frame = LibForecast.frame or CreateFrame("Frame");
    LibForecast.frame:RegisterEvent("CONSOLE_MESSAGE");
    LibForecast.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CONSOLE_MESSAGE" then
            local message = ...;
            local weatherType = string.match(message, "Weather changed to (%d+)");

            weatherType = tonumber(weatherType);

            if weatherType then
                LibForecast.callbacks:Fire("OnWeatherChanged", weatherType);
            end
        end
    end);
end
