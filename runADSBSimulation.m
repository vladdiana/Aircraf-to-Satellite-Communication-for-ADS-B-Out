function runADSBSimulation(depCoord, arrCoord, satelliteType)

    
    startTime = datetime(2024,10,9,8,30,0,'TimeZone','Europe/Bucharest');
    stopTime = startTime + hours(2) + minutes(30);
    sampleTime = 10;
    sc = satelliteScenario(startTime, stopTime, sampleTime);
    viewer = satelliteScenarioViewer(sc);

    
    airports = groundStation(sc, ...
        [depCoord(1), arrCoord(1)], ...
        [depCoord(2), arrCoord(2)], ...
        Name=["Departure", "Arrival"]);

    
    waypoints = [
        depCoord(1), depCoord(2), 3;
        43.5, 28.5, 3000;
        41.5, 30.0, 11000;
        38.0, 32.0, 11000;
        36.0, 33.0, 9000;
        arrCoord(1), arrCoord(2), 3];
    timeOfArrival = duration(["00:00:00"; "00:15:00"; "00:50:00"; "01:30:00"; "02:10:00"; "02:30:00"]);
    trajectory = geoTrajectory(waypoints, seconds(timeOfArrival));
    aircraft = platform(sc, trajectory, Name="Aircraft", Visual3DModel="CesiumAir.glb");
    camtarget(viewer, aircraft);

    
    numSat = 11;
    numOrb = 6;
    orbitIdx = repelem(1:numOrb, 1, numSat);
    planeIdx = repmat(1:numSat, 1, numOrb);
    RAAN = 180*(orbitIdx-1)/numOrb;
    trueAn = 360*(planeIdx-1 + 0.5*(mod(orbitIdx,2)-1))/numSat;
    a = (6371 + 780)*1e3;
    semimajoraxis = repmat(a, size(RAAN));
    inclination = repmat(86.4, size(RAAN));
    eccentricity = zeros(size(RAAN));
    argPeriapsis = zeros(size(RAAN));

    iridiumSatellites = satellite(sc, ...
        semimajoraxis, eccentricity, inclination, ...
        RAAN, argPeriapsis, trueAn, ...
        Name="Iridium " + string(1:66)');

    hide(iridiumSatellites.Orbit, viewer);
    show(iridiumSatellites(1:numSat:end).Orbit, viewer);

    
    conicalSensor(iridiumSatellites, "MaxViewAngle", 125);

    
    fADSB = 1090e6;
    aircraftADSBAntenna = arrayConfig("Size", [1 1]);
    aircraftADSBTransmitter = transmitter(aircraft, ...
        Antenna=aircraftADSBAntenna, ...
        Frequency=fADSB, ...
        Power=10*log10(150), ...
        MountingLocation=[8,0,-2.7], ...
        Name="ADS-B Aircraft Transmitter");

    
    airportADSBAntenna = arrayConfig("Size",[1 1]);
    airportADSBReceiver = receiver(airports, ...
        Antenna=airportADSBAntenna, ...
        Name=airports.Name + " Receiver");

    
    if strcmp(satelliteType, "Isotropic")
        satelliteADSBAntenna = arrayConfig("Size",[1 1]);
        satelliteADSBReceiver = receiver(iridiumSatellites, ...
            Antenna=satelliteADSBAntenna, ...
            MountingAngles=[0,0,0], ...
            Name=iridiumSatellites.Name + " Receiver");
    else
        satelliteADSBAntenna = HelperCustom48BeamAntenna(fADSB);
        satelliteADSBReceiver = receiver(iridiumSatellites, ...
            Antenna=satelliteADSBAntenna, ...
            MountingAngles=[0,-90,0], ...
            Name=iridiumSatellites.Name + " Receiver");
    end

    
    lnkADSB = link(aircraftADSBTransmitter, [airportADSBReceiver, satelliteADSBReceiver]);
    lnkADSB.LineColor = [1 0.4 0];
    lnkADSB.LineWidth = 1.5;
    show(lnkADSB, viewer);

    [eL, time] = ebno(lnkADSB);
    marginADSB = eL - repmat([airportADSBReceiver.RequiredEbNo, satelliteADSBReceiver.RequiredEbNo]', [1, size(eL,2)]);

    
    figure;
    plot(time, max(marginADSB), "b");
    title("ADS-B Out Link Margin vs. Time");
    xlabel("Timp");
    ylabel("Margin (dB)");
    grid on;

    
    viewer.PlaybackSpeedMultiplier = 5;
    play(sc);
end
