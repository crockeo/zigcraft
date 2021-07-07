#pragma once

namespace cppcraft {

template <typename T> class Guard {
public:
  Guard(T value, std::function<void(T)> teardown) {
    _value = value;
    _teardown = teardown;
  }

  ~Guard() { _teardown(_value); }

  T operator*() { return _value; }

private:
  T _value;
  std::function<void(T)> _teardown;
};

} // namespace cppcraft
