
function [ls, iterations, elapsed] = propagate_rprop(ls, time, LR_MAX, LR_MIN, LR_0, top, first_time, operator, varargin)

acc_factor = 1.2; %Constant
dec_factor = 0.5; %Constant

% Set some persistent variables to store momentum for next call
persistent old_grad_phi; %Old gradient
persistent lr;           %Individual learning rates
persistent XI;
persistent YI;
if(first_time)
    old_grad_phi = zeros(size(ls));
    lr           = zeros(size(ls)) + LR_0;
    nrows = size(old_grad_phi,1);
    ncols = size(old_grad_phi,2);
    [XI,YI] = meshgrid(1:ncols,1:nrows);
    XI = double(XI);
    YI = double(YI);
end

% Start counters
elapsed = 0;
iterations = 0;

% Save current level set phi and level set band
old_phi  = ls.phi;
old_band = ls.band;

% Do one iteration if the requested time is 0
if (time == 0)
    
    % Propagate the level set function in time
    [phi,dt] = ls.integrate(ls, Inf, operator, varargin{:});
    
    % Update level set function and exit
    ls.phi(ls.band) = phi;
    elapsed = dt;
    iterations = 1;

% Else, iterate until requested time is reached
else
    while (elapsed < time)

        % Propagate the level set function in time
        [phi,dt] = ls.integrate(ls, time-elapsed, operator, varargin{:});

        % Update level set function and continue
        ls.phi(ls.band) = phi;
        elapsed = elapsed + dt;
        iterations = iterations + 1;
    end    
end

iterations

% Rebuild the distance function and the narrowband
ls = rebuild_narrowband(ls);

% Compute the current gradient and extend values to the entire grid (if we
% have a narrowband)
common_band = intersect(ls.band, old_band);
[Y, X] = ind2sub(size(ls), common_band);
curr_grad_phi = griddata(double(X),double(Y),ls.phi(common_band) - old_phi(common_band),XI,YI,'nearest');

%RPROP
grad_sprod = sign(old_grad_phi .* curr_grad_phi);
acc_i  = grad_sprod > 0;
%null_i = grad_sprod == 0;
dec_i  = grad_sprod < 0;

lr(acc_i) = min(lr(acc_i) * acc_factor, LR_MAX);
lr(dec_i) = max(lr(dec_i) * dec_factor, LR_MIN);
delta_phi = lr .* sign(curr_grad_phi);
%delta_phi(dec_i) = 0; %In original RPROP, do not perform update if sign change
old_grad_phi = curr_grad_phi;
%old_grad_phi(dec_i) = 0; %In original RPROP, do not adapt lr in next iteration if sign change.

% Cut the rate of change so we don't move too fast
delta_phi(delta_phi > top) = top;
delta_phi(delta_phi < (-top)) = -top;


% Update level set function and reinitialize
ls.phi = old_phi + delta_phi;
ls = rebuild_narrowband(ls);

% Some plots for debugging
figure(44); hold off; clf;
subplot(3,2,1);imagesc(old_phi);colorbar;hold on; plot(ls, 'contour y');
subplot(3,2,2);imagesc(ls.phi);colorbar;hold on; plot(ls, 'contour y');
subplot(3,2,3);imagesc(curr_grad_phi);colorbar;hold on; plot(ls, 'contour y');
subplot(3,2,4);imagesc(delta_phi);colorbar;hold on; plot(ls, 'contour y');
subplot(3,2,5);imagesc(grad_sprod);colorbar;hold on; plot(ls, 'contour y');
drawnow;