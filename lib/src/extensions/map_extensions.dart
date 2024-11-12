extension MapX<K, V> on Map<K, V> {
  V1? getOrNull<V1>(K key) {
    if (containsKey(key)) {
      try {
        return this[key] as V1;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
