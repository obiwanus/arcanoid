#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "game.h"

#define COUNT_OF(x) \
  ((sizeof(x) / sizeof(0 [x])) / ((size_t)(!(sizeof(x) % sizeof(0 [x])))))

// Globals
bool g_running = true;
XImage *g_ximage;

int main(int argc, char *argv[]) {
  Display *display;
  Window window;

  const int kWindowWidth = 640;
  const int kWindowHeight = 480;

  // Open display
  display = XOpenDisplay(NULL);
  if (!display) {
    fprintf(stderr, "Failed to open X display\n");
    exit(1);
  }

  int screen = DefaultScreen(display);

  window = XCreateSimpleWindow(display, RootWindow(display, screen), 300, 300,
                               kWindowWidth, kWindowHeight, 0,
                               WhitePixel(display, screen),
                               BlackPixel(display, screen));
  XSetStandardProperties(display, window, "Arcanoid", "Hi!", None, NULL, 0,
                         NULL);
  XSelectInput(display, window, ExposureMask | KeyPressMask | KeyReleaseMask |
                                    ButtonPressMask | StructureNotifyMask);
  XMapRaised(display, window);

  GC gc;
  XGCValues gcvalues;
  Pixel_Buffer pixel_buffer = {0};

  // Create x image
  {
    for (;;) {
      XEvent e;
      XNextEvent(display, &e);
      if (e.type == MapNotify) break;  // wait for map notify event
    }
    g_ximage = XGetImage(display, window, 0, 0, kWindowWidth, kWindowHeight,
                         AllPlanes, ZPixmap);
    pixel_buffer.pixels = (u32 *)g_ximage->data;
    pixel_buffer.width = kWindowWidth;
    pixel_buffer.height = kWindowHeight;

    gc = XCreateGC(display, window, 0, &gcvalues);
  }

  Atom wmDeleteMessage = XInternAtom(display, "WM_DELETE_WINDOW", False);
  XSetWMProtocols(display, window, &wmDeleteMessage, 1);

  User_Input inputs[2];
  User_Input *old_input = &inputs[0];
  User_Input *new_input = &inputs[1];
  *new_input = (const User_Input){0};

  // Main loop
  g_running = true;

  while (g_running) {
    // Process events
    while (XPending(display)) {
      XEvent event;
      XNextEvent(display, &event);

      if (event.type == KeyPress || event.type == KeyRelease) {
        KeySym key;
        char buf[256];
        char symbol = 0;
        bool pressed = false;
        bool released = false;
        bool retriggered = false;

        if (XLookupString(&event.xkey, buf, 255, &key, 0) == 1) {
          symbol = buf[0];
        }

        // Process user input
        if (event.type == KeyPress) {
          pressed = true;
        }

        if (event.type == KeyRelease) {
          if (XEventsQueued(display, QueuedAfterReading)) {
            XEvent nev;
            XPeekEvent(display, &nev);

            if (nev.type == KeyPress && nev.xkey.time == event.xkey.time &&
                nev.xkey.keycode == event.xkey.keycode) {
              // Ignore. Key wasn't actually released
              XNextEvent(display, &event);
              retriggered = true;
            }
          }

          if (!retriggered) {
            released = true;
          }
        }

        if (pressed || released) {
          if (key == XK_Escape) {
            new_input->buttons[IB_escape] = pressed;
          }
          if (key == XK_Up) {
            new_input->buttons[IB_up] = pressed;
          }
          if (key == XK_Down) {
            new_input->buttons[IB_down] = pressed;
          }
          if (key == XK_Left) {
            new_input->buttons[IB_left] = pressed;
          }
          if (key == XK_Right) {
            new_input->buttons[IB_right] = pressed;
          }
          if (key == XK_Shift_L || key == XK_Shift_R) {
            new_input->buttons[IB_shift] = pressed;
          }
          if (('a' <= symbol && symbol <= 'z') ||
              ('A' <= symbol && symbol <= 'Z') ||
              ('0' <= symbol && symbol <= '9')) {
            // Convert small letters to capitals
            if ('a' <= symbol && symbol <= 'z') {
              symbol += ('A' - 'a');
            }
            // new_input->buttons[IB_key] = pressed;
            // new_input->symbol = symbol;
          }
        }
      }

      // Close window message
      if (event.type == ClientMessage) {
        if ((unsigned)event.xclient.data.l[0] == wmDeleteMessage) {
          g_running = false;
        }
      }
    }

    bool result = update_and_render(&pixel_buffer, new_input);
    if (!result) {
      g_running = false;
    }

    XPutImage(display, window, gc, g_ximage, 0, 0, 0, 0, kWindowWidth,
              kWindowHeight);

    // Swap inputs
    struct User_Input *tmp = old_input;
    old_input = new_input;
    new_input = tmp;

    // Zero input
    *new_input = (const User_Input){0};
    new_input->old = old_input;  // Save so we can refer to it later

    // Retain the button state
    for (size_t i = 0; i < COUNT_OF(new_input->buttons); i++) {
      new_input->buttons[i] = old_input->buttons[i];
    }
  }

  XDestroyWindow(display, window);
  XCloseDisplay(display);

  exit(0);
}