function antenna = HelperCustom48BeamAntenna(frequencyHz)

    az = -180:5:180;
    el = -90:5:90;
    [AZ, EL] = meshgrid(az, el);

    gainPattern = -min(20*log10(1 + (AZ/30).^2 + (EL/20).^2), 50);
    phasePattern = zeros(size(gainPattern));

    antenna = phased.CustomAntennaElement( ...
        'AzimuthAngles', az, ...
        'ElevationAngles', el, ...
        'MagnitudePattern', gainPattern, ...
        'PhasePattern', phasePattern);
end
