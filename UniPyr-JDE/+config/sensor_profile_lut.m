function [a_iso, b_iso, layer_scale_iso] = sensor_profile_lut(iso, sensor_name)
% SENSOR_PROFILE_LUT  读取物理/等效噪声参数，优先从 calibrated_profiles/*.mat 加载全流标定库
    if nargin < 2 || isempty(sensor_name), sensor_name = 'default_cmos'; end
    layer_scale_iso = [1.0, 0.75, 0.55]; % 默认三层比例

    % 自动定位 UniPyr-JDE/calibrated_profiles/<sensor_name>.mat
    this_dir = fileparts(mfilename('fullpath'));
    jdef_root = fileparts(this_dir);
    mat_path = fullfile(jdef_root, 'calibrated_profiles', [lower(sensor_name) '.mat']);

    if exist(mat_path, 'file')
        S = load(mat_path, 'cal_db');
        cal = S.cal_db;
        iso_q = min(max(iso, cal.iso_list(1)), cal.iso_list(end));
        a_iso = interp1(cal.iso_list, cal.a_eff, iso_q, 'linear');
        b_iso = interp1(cal.iso_list, cal.b_eff, iso_q, 'linear');
        if isfield(cal, 'layer_noise_scale')
            for l = 1:3
                layer_scale_iso(l) = interp1(cal.iso_list, cal.layer_noise_scale(:, l), iso_q, 'linear');
            end
        end
        return;
    end

    % 若未找到实测 .mat 标定库，回退到内置默认参数
    switch lower(sensor_name)
        case 'default_cmos'
            iso_pts = [100,    400,     1600,    3200,    6400,    12800];
            a_pts   = [3.5e-5, 1.4e-4,  5.5e-4,  1.1e-3,  2.2e-3,  4.4e-3];
            b_pts   = [0.0003, 0.0007,  0.0022,  0.0045,  0.0090,  0.0180].^2;
        case 'dual_gain_cmos'
            iso_pts = [100,    400,     799,     800,     1600,    3200,    6400];
            a_pts   = [3.5e-5, 1.4e-4,  2.8e-4,  2.8e-4,  5.5e-4,  1.1e-3,  2.2e-3];
            b_pts   = [0.0003, 0.0009,  0.0017,  0.0008,  0.0015,  0.0030,  0.0060].^2;
        otherwise
            error('未找到传感器 %s 的标定文件 (%s)，请先运行 run_crvd_calibration！', sensor_name, mat_path);
    end

    iso_q = min(max(iso, iso_pts(1)), iso_pts(end));
    a_iso = interp1(iso_pts, a_pts, iso_q, 'linear');
    b_iso = interp1(iso_pts, b_pts, iso_q, 'linear');
end