class RunOnceProcess {
  bool onTheRun = false;
  bool done = false;

  Future<void> executeOnce(Future<bool> Function() execute) async {
    if (done) {
      return;
    }
    while (onTheRun) {
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!done) {
      onTheRun = true;
      try {
        done = await execute();
      } finally {
        onTheRun = false;
      }
    }
  }
}
