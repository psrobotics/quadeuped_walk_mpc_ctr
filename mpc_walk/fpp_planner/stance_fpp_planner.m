function [ref_fpp_traj, ref_contact_event, fpp_mat_now, fpp_mat_next, fpp_u_flag]...
    = stance_fpp_planner(state_traj, vel_tar_local, fpp_mat_now, fpp_mat_next, fpp_u_flag, world_p, body_p, ctr_p)
% plan and combine stance swing fpps, and contact matrix from target
% velocity and gait clocks

% update local clock based on current time
% add a tiny time offset avoid t=0 situation
t_global_n = ctr_p.t_gloal_n + 1e-8;

t_gait = ctr_p.t_gait;
dt_mpc = ctr_p.dt_mpc;

% pick up local contact event mat
contact_mat = ones(4,4);
t_local_stance = 0.5; % ori 0.25
t_global_stance = t_local_stance * ctr_p.t_gait;
if ctr_p.gait_tar == 1 % trot
    contact_mat = ctr_p.contact_trot;
elseif ctr_p.gait_tar == 2 % pace
    contact_mat = ctr_p.contact_pace;
elseif ctr_p.gait_tar == 3 % bounding
    contact_mat = ctr_p.contact_bound;
elseif ctr_p.gait_tar == 4 % gallop
    contact_mat = ctr_p.contact_gallop;
else
    error('unknown gait defined');
end

% init ref contact event, 4*N
ref_contact_event = ones(4, ctr_p.mpc_horizon_steps);
% init ref fpp, 12*n
ref_fpp_traj = zeros(12, ctr_p.mpc_horizon_steps);

% get com to hip vec for 4 legs
hip_vec_s = [body_p.length/2; body_p.width/2; 0];
hip_dir_mat = [1 1 -1 -1; 1 -1 1 -1; 0 0 0 0];
% each col is a hip vec
hip_vec = hip_dir_mat .* repmat(hip_vec_s,1,4);

% check if fisrt enter a gait cycle

eps = 1e-4;

% init now fpp arr and next fpp arr, z=0


for k=1:ctr_p.mpc_horizon_steps
    % local gait process, 0~1
    t_local_gait_n = (mod(t_global_n, t_gait)) / t_gait; 
    % there's problem with mod's precision
    % t_local_gait_n = (high_precision_fmod(t_global_n, t_gait, 20)) / t_gait;

    
    % which phase current gait in, 4 phases in total, 1~4
    phase_local_gait_n = ceil(t_local_gait_n/0.25);
    % fill current contact event
    ref_contact_event(:,k) = contact_mat(:,phase_local_gait_n);

    if (phase_local_gait_n==1 && fpp_u_flag==0) || (phase_local_gait_n==3 && fpp_u_flag==0)
    %if (abs(t_local_gait_n-0)<eps || abs(t_local_gait_n-0.5)<eps)
        fprintf('calc next fpp with t_l %f, g_t %f, phase %d, flag %d \n',...
            t_local_gait_n, t_global_n, phase_local_gait_n, fpp_u_flag);
        % update current fpp
        fpp_mat_now = fpp_mat_next;
        %%%%%%%%%%%%%%%%%%%%
        fpp_u_flag = 1;
        % when first enter phase 1 or 3, calc next stance fpp
        rot_mat_t = rot_zyx(state_traj(1:3,k));
        % get global target linear velocity (v cmd in global coord)
        xyz_vel_global = rot_mat_t*vel_tar_local(4:6);
        p_symmetry = t_global_stance/2*state_traj(10:12,k) + ...
                     ctr_p.gait_k_p*(state_traj(10:12,k)-xyz_vel_global);
        com_z = state_traj(6,k);
        %foot_z = ctr_p.gait_h;
        p_cent = 0.5*sqrt(com_z/world_p.g) * ...
                 cross(state_traj(10:12,k),vel_tar_local(1:3));
        for leg_k = 1:4
            p_shoulder = state_traj(4:6,k) + ...
                         rot_mat_t*hip_vec(:,leg_k);
            p_next = p_shoulder+p_symmetry+p_cent;
            % set locol fpp z height (=0 if no terrain sensor)
            p_next(3) = 0;
            fpp_mat_next(:,leg_k) = p_next;
        end

        fpp_mat_now
        fpp_mat_next
        
    elseif (t_local_gait_n > 0.3 && t_local_gait_n < 0.4 && fpp_u_flag==1) || (t_local_gait_n > 0.8 && t_local_gait_n < 0.9 && fpp_u_flag==1)
        fpp_u_flag = 0;
        fprintf('flag reset w phase %d, l_t %f, g_t %f\n', phase_local_gait_n, t_local_gait_n, t_global_n);
    end

    % fill leg fpp, stance - fpp_now, swing - swing traj
    for leg_k=1:4
        contact = ref_contact_event(leg_k,k);
        if contact % stance
            % just copy current stance fpp
            ref_fpp_traj((leg_k-1)*3+1:(leg_k-1)*3+3,k) = fpp_mat_now(:,leg_k);
        else % swing
            % local swing clock, 0~1, reset each half cycle
            t_local_swing_n = 2*mod(t_local_gait_n,0.5);
            fpp_start = fpp_mat_now(:,leg_k);
            fpp_end = fpp_mat_next(:,leg_k);
            % get swing leg traj at time k
            fpp_swing_t = swing_fpp_planner(fpp_start, fpp_end, ctr_p.gait_h, t_local_swing_n);
            ref_fpp_traj((leg_k-1)*3+1:(leg_k-1)*3+3,k) = fpp_swing_t;

            %fprintf('phase %d, swing leg %d, swing clock %f \n',phase_local_gait_n,leg_k,t_local_swing_n);
            %fprintf('x start %f, x end %f \n',fpp_start(1),fpp_end(1));
        end
    end

    t_global_n = t_global_n + dt_mpc;
end

end
