function [a_iso, b_iso, layer_scale_iso] = sensor_profile_lut(iso, sensor_name)
% SENSOR_PROFILE_LUT  读取物理/等效噪声参数，并按当前传感器自身的增益平方律自动补全极小截距
    if nargin < 2 || isempty(sensor_name), sensor_name = 'default_cmos'; end
    layer_scale_iso = [1.0, 0.75, 0.55];

    this_dir = fileparts(mfilename('fullpath'));
    jdef_root = fileparts(this_dir);
    mat_path = fullfile(jdef_root, 'calibrated_profiles', [lower(sensor_name) '.mat']);

    if exist(mat_path, 'file')
        S = load(mat_path, 'cal_db');
        cal = S.cal_db;

        % 通用物理规律：若某传感器在低 ISO 下因读出噪声极小导致拟合截距 b==0，
        % 用该传感器自身测出有效 b 的最高 ISO 档位按增益平方律推算底盘（不依赖任何特定设备常数）
        b_arr = cal.b_eff;
        valid_b = find(b_arr > 1e-8);
        if ~isempty(valid_b)
            ref_idx = valid_b(end);
            for k = 1:numel(b_arr)
                if b_arr(k) <= 1e-8
                    b_arr(k) = b_arr(ref_idx) * (cal.iso_list(k) / cal.iso_list(ref_idx))^2;
                end
            end
        end

        iso_q = min(max(iso, cal.iso_list(1)), cal.iso_list(end));
        a_iso = interp1(cal.iso_list, cal.a_eff, iso_q, 'linear');
        b_iso = interp1(cal.iso_list, b_arr,     iso_q, 'linear');
        if isfield(cal, 'layer_noise_scale')
            for l = 1:3
                layer_scale_iso(l) = interp1(cal.iso_list, cal.layer_noise_scale(:, l), iso_q, 'linear');
            end
        end
        return;
    end

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
            error('未找到传感器 %s 的标定文件 (%s)', sensor_name, mat_path);
    end

    iso_q = min(max(iso, iso_pts(1)), iso_pts(end));
    a_iso = interp1(iso_pts, a_pts, iso_q, 'linear');
    b_iso = interp1(iso_pts, b_pts, iso_q, 'linear');
end
