################################################################################
# Toy Example
################################################################################
T = Float64

# Define the dynamics of the system
p = 4 # Number of players
model = UnicycleGame(p=p) # game with 3 players with unicycle dynamics
n = model.n
m = model.m

# Define the horizon of the problem
N = 20 # N time steps
dt = 0.1 # each step lasts 0.1 second
probsize = ProblemSize(N,model) # Structure holding the relevant sizes of the problem

# Define the objective of each player
# We use a LQR cost
Q = [Diagonal(10*ones(SVector{model.ni[i],T})) for i=1:p] # Quadratic state cost
R = [Diagonal(0.1*ones(SVector{model.mi[i],T})) for i=1:p] # Quadratic control cost
# Desrired state
xf = [SVector{model.ni[1],T}([2,+0.4,0,0]),
      SVector{model.ni[2],T}([2, 0.0,0,0]),
      SVector{model.ni[3],T}([3,-0.4,0,0]),
      SVector{model.ni[4],T}([3,+0.8,0,0]),
      ]
# Desired control
uf = [zeros(SVector{model.mi[i],T}) for i=1:p]
# Objectives of the game
game_obj = GameObjective(Q,R,xf,uf,N,model)

# Define the constraints that each player must respect
game_con = GameConstraintValues(probsize)
# Add collision avoidance
radius = 0.05
add_collision_avoidance!(game_con, probsize, radius)
# Add control bounds
u_max =  100*ones(SVector{m,T})
u_min = -100*ones(SVector{m,T})
add_control_bound!(game_con, probsize, u_max, u_min)
# Add wall constraint
walls = [Wall([0.5,-0.5], [1.5,0.5], [1.,-1.]/sqrt(2))]
add_wall_constraint!(game_con, probsize, walls)
# Add circle constraint
xc = [1., 2., 3.]
yc = [1., 2., 3.]
radius = [0.1, 0.2, 0.3]
add_circle_constraint!(game_con, probsize, xc, yc, radius)

# Define the initial state of the system
x0 = SVector{model.n,T}([
    0.0, 0.0, 0.5, 0.0,
   -0.4, 0.0, 0.4, 0.6,
    0.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 0.0, 0.0,
    ])

# Define the Options of the solver
opts = Options()

# Define the game problem
prob = GameProblem(N,dt,x0,model,opts,game_obj,game_con)

# Solve the problem
@time newton_solve!(prob)
# @profiler newton_solve!(prob)

plot_traj!(prob.model, pdtraj0.pr)


pdtraj0 = PrimalDualTraj(probsize,dt)
init_traj!(pdtraj0, f=rand, amplitude=1e3)
game_con = GameConstraintValues(probsize)
add_control_bound!(game_con, probsize, u_max, u_min)
cval = game_con.control_conval[1]
TrajectoryOptimization.evaluate!(cval, pdtraj0.pr)
TrajectoryOptimization.max_violation!(cval)
cval.c_max
# Altro.violation!(cval)



a = 10
a = 10
a = 10
a = 10

# add violation statistics
# add cost statistics
# add AL cost statistics
# add dual ascent
# add inner loop violaion and residual threshold
# add outer loop violaion and residual threshold