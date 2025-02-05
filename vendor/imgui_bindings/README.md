Bindings generated using [dear bindings](https://github.com/dearimgui/dear_bindings)

**:warning: SSE might need to be disabled for ImGui**: Can be done by uncommenting `#define IMGUI_DISABLE_SSE` in *imgui/imconfig.h*

##### Used commands

```shel
python dear_bindings.py -o dcimgui ../imgui_bindings/imgui/imgui.h --custom-namespace-prefix ig
python dear_bindings.py --backend -o dcimgui_impl_glfw ../imgui_bindings/imgui/imgui_impl_glfw.h 
python dear_bindings.py --backend -o dcimgui_impl_opengl3 ../imgui_bindings/imgui/imgui_impl_opengl3.h
```

