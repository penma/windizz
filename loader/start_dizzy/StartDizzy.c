#include <windows.h>
int main() {
	ShellExecute(NULL, "open", "loader\\setup\\Loader.exe", NULL, NULL, SW_SHOWNORMAL);
}
