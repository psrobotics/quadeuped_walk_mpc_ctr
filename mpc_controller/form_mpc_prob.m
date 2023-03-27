%% Get all constraints in a mpc cycle

function [mpc_v, mpc_c] = form_mpc_prob(path, world_p, body_p, ctr_p)

addpath(path.casadi);
import casadi.*;

%% Casadi variables array in one prediction widow
mpc_v.x_arr = SX.sym('x_arr', body_p.state_dim, ctr_p.N+1); % state
mpc_v.f_arr = SX.sym('f_arr', body_p.f_dim, ctr_p.N); % foot force / input
mpc_v.fp_arr = SX.sym('fp_arr', body_p.fp_dim, ctr_p.N); % foot position

%% Reference traj
mpc_v.x_ref_arr = SX.sym('x_ref_arr', body_p.state_dim, ctr_p.N+1); % state
mpc_v.f_ref_arr = SX.sym('f_ref_arr', body_p.f_dim, ctr_p.N); % foot force
mpc_v.fp_ref_arr = SX.sym('fp_ref_arr', body_p.fp_dim, ctr_p.N); % foot position
% contact mat arr, which the leg touches ground, set by fpp_planner
% only foot on ground can output a ground reaction force
mpc_v.contact_mat_arr = SX.sym('contact_mat_arr', 4, N);

%% Constraints
N = ctr_p.N;
state_dim = body.state_dim; % number of dim of state, rpy xyz dot_rpy dot_xyz
f_dim = body.f_dim; % number of dim of leg force, 3*4
fp_dim = body.fp_dim; % number of dim of leg pos, 3*4

% equal constraints
mpc_c.eq_con_dynamic = SX.zeros(state_dim*(N+1),1); % dynamic constraint, 12*(N+1),1
mpc_c.eq_con_foot_contact_ground = SX.zeros(4*N,1); % constraint on leg's motion range, 4*N,1
mpc_c.eq_con_foot_non_slip = SX.zeros(fp_dim*N,1); % constraint on foot's non slip stane phase, 12*N,1
mpc_c.eq_con_init_state = mpc_v.x_ref_arr(:,1)-mpc_v.x_arr(:,1); % set init condition constraint, 12,1

mpc_c.eq_con_dim = state_dim*(N+1) + 4*N + fp_dim*N + 12; % dim for eq constraints

% inequal constraints 
mpc_c.ineq_con_foot_range = SX.zeros(4*6*N,1); % ieq constraint on foot's motion range 4leg*3axis*2dir
mpc_c.ineq_con_foot_friction = SX.zeros(4*4*N,1); % ieq constraint on foot friction 4*2axis*2dir
mpc_c.ineq_con_zforce_dir = SX.zeros(1*N,1); % z axis force always pointing up
mpc_c.ineq_con_zforce_range = SX.zeros(4*N,1); % z axis force range, swing phase ->0, stance phase -> < max z force

mpc_c.ineq_con_dim = 4*6*N + 4*4*N + N + 4*N; % dim for ieq constraints

end

