// system/socket headers live at the top of snes.hpp (this file is included inside namespace SNES)

#if defined(_WIN32)
  typedef SOCKET xband_socket_t;
  #define XBAND_INVALID_SOCKET INVALID_SOCKET
  static inline bool xband_net_init() {
    static bool ok = false;
    if(!ok) { WSADATA wsa; ok = WSAStartup(MAKEWORD(2, 2), &wsa) == 0; }
    return ok;
  }
  static inline int  xband_sock_send(xband_socket_t s, const void *b, size_t n) { return ::send(s, (const char*)b, (int)n, 0); }
  static inline int  xband_sock_recv(xband_socket_t s, void *b, size_t n) { return ::recv(s, (char*)b, (int)n, 0); }
  static inline void xband_sock_close(xband_socket_t s) { ::closesocket(s); }
  static inline void xband_sock_nonblock(xband_socket_t s) { u_long on = 1; ::ioctlsocket(s, FIONBIO, &on); }
#else
  typedef int xband_socket_t;
  #define XBAND_INVALID_SOCKET (-1)
  static inline bool xband_net_init() { return true; }
  static inline int  xband_sock_send(xband_socket_t s, const void *b, size_t n) { return (int)::send(s, b, n, 0); }
  static inline int  xband_sock_recv(xband_socket_t s, void *b, size_t n) { return (int)::recv(s, b, n, 0); }
  static inline void xband_sock_close(xband_socket_t s) { ::close(s); }
  static inline void xband_sock_nonblock(xband_socket_t s) { ::fcntl(s, F_SETFL, ::fcntl(s, F_GETFL, 0) | O_NONBLOCK); }
#endif

#define XBAND_REGS 0xE0

class XBANDBase : public Coprocessor, public Memory  {
public:
  MappedRAM sram;

  void init();
  void load();
  void unload();
  void power();
  void reset();
  void enable();
  static void Enter();
  void enter();

  uint8 memory_access(bool write, Memory &memory, unsigned addr, uint8 data);
  uint8 memory_read(Memory &memory, unsigned addr);
  void memory_write(Memory &memory, unsigned addr, uint8 data);

  uint8 mcu_access(bool write, unsigned addr, uint8 data = 0x00);
  uint8 mcu_read(unsigned addr);
  void mcu_write(unsigned addr, uint8 data);

  uint8 mmio_read(unsigned addr);
  void mmio_write(unsigned addr, uint8 data);

  uint8 read(unsigned addr);
  void write(unsigned addr, uint8 data);

  void serialize(serializer&);

  void xband_send_identity();
  void debug_modem_registers();
  
  struct XBANDModem {
    uint8_t line_relay;
    uint8_t regs[0x20];
    uint8_t set_ATV25;
  };

  struct XBANDState {
    uint16_t cart_space[0x200000];
    uint8_t regs[XBAND_REGS];
    uint8_t kill;
    uint8_t control;
    struct sockaddr_in server;
    xband_socket_t conn;
    uint8_t modem_line_relay;
    uint8_t modem_regs[0x20];
    uint8_t modem_set_ATV25;
    uint8_t net_step;
    uint8_t rxbuf[16384];
    uint32_t rxbufpos;
    uint32_t rxbufused;
    uint8_t txbuf[16384];
    uint32_t txbufpos;
    uint32_t txbufused;
  };

private:
  uint8 mapset;
  //is this really how this works? How do struct objects work
  //in C++ as opposed typedef'd struct pointers in C ?
  //xband_state *x, obj;
  //x = &obj;
  
  bool read_96;
};

class XBANDCart : public Memory {
  public:
    void init();
    void load();
    void unload();
    void power();
    void reset();
    void enable();

    void serialize(serializer&);

    uint8 read(unsigned addr);
    void write(unsigned addr, uint8 data);

    uint8 memory_read(Memory &memory, unsigned addr);
    void memory_write(Memory &memory, unsigned addr, uint8 data);

    XBANDCart();
    ~XBANDCart();
  
  private:
    uint8 mapset;
  
    bool read_96;
};

extern XBANDBase  xband_base;
extern XBANDCart  xband_cart;
