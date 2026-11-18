function [x_lut, gamma_lut] = gamma_curves(curve_type, lut_N)
% GAMMA_CURVES  生成标准或自定义的 1D Gamma 查找表
    if nargin < 1 || isempty(curve_type), curve_type = 'srgb'; end
    if nargin < 2 || isempty(lut_N), lut_N = 1024; end

    x_lut = linspace(0, 1, lut_N);
    switch lower(curve_type)
        case 'srgb'
            gamma_lut = zeros(size(x_lut));
            m = x_lut <= 0.0031308;
            gamma_lut(m)  = 12.92 * x_lut(m);
            gamma_lut(~m) = 1.055 * (x_lut(~m).^(1/2.4)) - 0.055;

        case 'bt709'
            gamma_lut = zeros(size(x_lut));
            m = x_lut < 0.018;
            gamma_lut(m)  = 4.5 * x_lut(m);
            gamma_lut(~m) = 1.099 * (x_lut(~m).^0.45) - 0.099;

        case 'gamma22'
            % 纯幂律带暗部微斜率封顶，避免 x=0 导数无穷大
            gamma_lut = min(x_lut.^(1/2.2), 15.0 * x_lut + 0.03);
            gamma_lut = x_lut.^(1/2.2); % 若用于查找表差分，推荐实际管线里采用带限制的 LUT
            m = x_lut < 0.002;
            k_cap = (0.002^(1/2.2)) / 0.002;
            gamma_lut(m) = k_cap * x_lut(m);

        otherwise
            error('不支持的 Gamma 曲线类型: %s', curve_type);
    end
end