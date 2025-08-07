function ADSBSimulation_GUI
    fig = figure('Name','ADS-B Out Simulation', ...
        'Position',[100 100 600 500], ...
        'Color',[0.8 0.9 1], ...
        'NumberTitle','off', ...
        'Resize','on');

    
    axLogo = axes('Parent', fig, 'Units','pixels', 'Position',[450 400 140 80]);
    try
        imshow('logo_utcn.jpg', 'Parent', axLogo);
    catch
        text(0,0.5,'Logo UTCN','Parent',axLogo,'FontSize',12,'FontWeight','bold');
    end
    axis off

    
    uicontrol('Style','text','Position',[150 440 300 30], ...
        'String','ADS-B Out Aircraft Simulation', ...
        'FontSize',14,'FontWeight','bold', ...
        'BackgroundColor',[0.8 0.9 1], ...
        'ForegroundColor',[0 0.2 0.4]);

    
    labels = {'Latitudine Plecare','Longitudine Plecare','Latitudine Sosire','Longitudine Sosire'};
    defaults = {'44.5711','26.0850','34.8756','33.6248'};
    positions = [390, 350, 310, 270];
    inputs = gobjects(1,4);

    for i = 1:4
        uicontrol('Style','text','Position',[50 positions(i) 140 25],'String',labels{i}, ...
            'BackgroundColor',[0.8 0.9 1],'FontSize',10,'FontWeight','bold','HorizontalAlignment','left');
        inputs(i) = uicontrol('Style','edit','Position',[200 positions(i) 120 25],'String',defaults{i},'FontSize',10);
    end

    
    uicontrol('Style','text','Position',[50 230 140 25],'String','Tipul de Satelit', ...
        'BackgroundColor',[0.8 0.9 1],'FontSize',10,'FontWeight','bold','HorizontalAlignment','left');
    satMenu = uicontrol('Style','popupmenu','Position',[200 230 150 25], ...
        'String',{'Isotropic','Custom 48-Beam'},'FontSize',10);

    
    uicontrol('Style','pushbutton','Position',[200 180 150 35],'String','Start Simulare', ...
        'FontSize',11,'FontWeight','bold','BackgroundColor',[0.2 0.6 1],'ForegroundColor','white', ...
        'Callback', @(~,~)runSim());

    uicontrol('Style','pushbutton','Position',[100 130 180 30],'String','Afișează Traiectorie', ...
        'FontSize',10,'BackgroundColor',[0.4 0.7 0.7],'ForegroundColor','white', ...
        'Callback', @(~,~)plotFlightPath());

    uicontrol('Style','pushbutton','Position',[320 130 180 30],'String','Vizibilitate Sateliți', ...
        'FontSize',10,'BackgroundColor',[0.2 0.6 0.7],'ForegroundColor','white', ...
        'Callback', @(~,~)plotSatelliteVisibility());

    uicontrol('Style','pushbutton','Position',[200 80 200 30],'String','Deschide Documentația', ...
        'FontSize',10,'BackgroundColor',[0.8 0.4 0.4],'ForegroundColor','white', ...
        'Callback', @(~,~)open('Proiect_RC_Denisa_Diana.docx'));

    

    function runSim()
        depCoord = [str2double(inputs(1).String), str2double(inputs(2).String)];
        arrCoord = [str2double(inputs(3).String), str2double(inputs(4).String)];
        satelliteType = satMenu.String{satMenu.Value};
        runADSBSimulation(depCoord, arrCoord, satelliteType);
    end

    function plotFlightPath()
        depCoord = [str2double(inputs(1).String), str2double(inputs(2).String)];
        arrCoord = [str2double(inputs(3).String), str2double(inputs(4).String)];
        waypoints = [
            depCoord(1), depCoord(2), 3;
            43.5, 28.5, 3000;
            41.5, 30.0, 11000;
            38.0, 32.0, 11000;
            36.0, 33.0, 9000;
            arrCoord(1), arrCoord(2), 3];
        timeOfArrival = duration(["00:00:00";"00:15:00";"00:50:00";"01:30:00";"02:10:00";"02:30:00"]);
        trajectory = geoTrajectory(waypoints, seconds(timeOfArrival));
        LLA = lookupPose(trajectory, 0:10:max(seconds(timeOfArrival)));
        figure;
        geoplot(LLA(:,1), LLA(:,2), 'b-', 'LineWidth', 1.5);
        geolimits([min(LLA(:,1))-1, max(LLA(:,1))+1], [min(LLA(:,2))-1, max(LLA(:,2))+1]);
        title('Traiectorie Zbor');
        geobasemap topographic;
    end

    function plotSatelliteVisibility()
        depCoord = [str2double(inputs(1).String), str2double(inputs(2).String)];
        arrCoord = [str2double(inputs(3).String), str2double(inputs(4).String)];
        startTime = datetime(2024,10,9,8,30,0,'TimeZone','Europe/Bucharest');
        stopTime = startTime + hours(2) + minutes(30);
        sc = satelliteScenario(startTime, stopTime, 10);
        waypoints = [
            depCoord(1), depCoord(2), 3;
            43.5, 28.5, 3000;
            41.5, 30.0, 11000;
            38.0, 32.0, 11000;
            36.0, 33.0, 9000;
            arrCoord(1), arrCoord(2), 3];
        timeOfArrival = duration(["00:00:00";"00:15:00";"00:50:00";"01:30:00";"02:10:00";"02:30:00"]);
        trajectory = geoTrajectory(waypoints, seconds(timeOfArrival));
        aircraft = platform(sc, trajectory);
        numSat = 11; numOrb = 6;
        RAAN = 180*(repelem(1:numOrb, numSat)-1)/numOrb;
        truean = 360*(repmat(1:numSat,1,numOrb)-1 + 0.5*(mod(repelem(1:numOrb,1,numSat),2)-1))/numSat;
        semiaxis = repmat((6371+780)*1e3, size(RAAN));
        incl = repmat(86.4, size(RAAN));
        iridium = satellite(sc, semiaxis, zeros(size(RAAN)), incl, RAAN, zeros(size(RAAN)), truean);
        sensors = conicalSensor(iridium, "MaxViewAngle", 125);
        acAccess = access(aircraft, sensors);
        [sStat, time] = accessStatus(acAccess);
        visData = double(sStat); visData(visData == 0) = NaN;
        visData = visData + (0:numel(iridium)-1)';
        figure;
        plot(time, visData, ".", "Color", "blue");
        title("Vizibilitate Sateliți Iridium");
        xlabel("Timp"); ylabel("Sateliți activi");
        yticks(1:5:66);
        grid on;
    end
end
