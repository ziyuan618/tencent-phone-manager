// Bridging.h - 内核模块桥接
// 这些函数由 libxpf / kfd framework 提供

// 内核读写
extern int kfd_init(void);
extern uint64_t kread64(uint64_t addr);
extern uint32_t kread32(uint64_t addr);

// 进程查找
extern int find_game_pid(void);
extern uint64_t get_proc_task(int pid);

// 游戏内存结构
// UE4 offsets (由 xpf_find_* 动态查找)
typedef struct {
    uint64_t gworld;
    uint64_t gnames;
    uint64_t ulevel;
    uint64_t actor_array;
    uint64_t actor_count;
    uint64_t game_instance;
    uint64_t local_player;
    uint64_t player_controller;
    uint64_t camera_manager;
    uint64_t root_component;
    // 摄像机
    float camera_location[3];
    float camera_rotation[3];
    float fov;
    // 矩阵
    float view_matrix[16];
    float proj_matrix[16];
} GameState;

extern GameState g_game_state;
extern int init_game_offsets(void);
