CFLAGS = -mwindows
LDFLAGS = -mwindows
CC = i586-mingw32msvc-gcc
STRIP = i586-mingw32msvc-strip

all: StartDizzy.exe

sfxdata.o: sfxdata.rc
	i586-mingw32msvc-windres $^ $@

StartDizzy.o: %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $^

StartDizzy.exe: StartDizzy.o
	$(CC) $(LDFLAGS) -o $@ $^
	$(STRIP) $@

clean:
	$(RM) *.o StartDizzy.exe
