function visualize_pipeline(RGB_in, RGB_out, dbg, RGB_gt)
% VISUALIZE_PIPELINE  展示工程调试六宫格视图
    figure('Name', 'UniPyr-JDE Pipeline Debug View', 'Position', [80, 80, 1320, 720]);
    subplot(2, 3, 1); imshow(RGB_in);
    title('输入: LTM + Gamma 后带噪图');

    subplot(2, 3, 2); imshow(RGB_out);
    title('输出: UniPyr-JDE 去噪与增强');

    if nargin >= 4 && ~isempty(RGB_gt)
        subplot(2, 3, 3); imshow(RGB_gt);
        title('参考真值: 无噪 LTM + Gamma 图');
    else
        subplot(2, 3, 3); imshow(abs(RGB_out - RGB_in) * 4);
        title('处理差异 (×4 放大)');
    end

    subplot(2, 3, 4); imagesc(dbg.sigma_0); colorbar; axis image off;
    title('还原噪声标准差场 \sigma_0(Y, g, W_{eff})');

    subplot(2, 3, 5); imagesc(dbg.a0, [0 1]); colorbar; axis image off;
    title('L0 引导滤波结构置信度 a_0');

    subplot(2, 3, 6); imagesc(dbg.gain_map_0); colorbar; axis image off;
    title('L0 五重门控增强增益 Gain_0');
end