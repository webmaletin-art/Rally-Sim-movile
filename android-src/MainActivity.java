package com.gskorp.rallysim;

import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;
import java.util.ArrayList;
import java.util.List;

/* Pantalla completa inmersiva: sin barra de notificaciones ni botones de Android.
   - La ventana se configura UNA sola vez (antes se reconfiguraba cada 2 s y eso hacía titilar la pantalla).
   - Si las barras aparecen (deslizando desde un borde con el volante o el pedal), se esconden al instante:
     se detecta por los "insets" de la ventana y, por las dudas, se revisa cada medio segundo sin tocar nada si ya están escondidas.
   - Los bordes de abajo (donde están el volante y el pedal) no disparan el gesto de "atrás" de Android 10+.
   - La pantalla no se apaga mientras se juega. */
public class MainActivity extends BridgeActivity {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private boolean resumed = false;
    private WindowInsetsControllerCompat ctl;
    private final Runnable hideNow = this::hideBars;
    private final Runnable watch = new Runnable() {
        @Override public void run() {
            if (!resumed) return;
            if (hasWindowFocus() && barsVisible()) hideBars();
            handler.postDelayed(this, 500);
        }
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window w = getWindow();
        w.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        w.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            WindowManager.LayoutParams lp = w.getAttributes();
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            w.setAttributes(lp);
        }
        WindowCompat.setDecorFitsSystemWindows(w, false);
        final View decor = w.getDecorView();
        ctl = WindowCompat.getInsetsController(w, decor);
        ctl.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        hideBars();
        /* Android 11+: aparecen barras → se esconden enseguida */
        ViewCompat.setOnApplyWindowInsetsListener(decor, (v, insets) -> {
            if (insets.isVisible(WindowInsetsCompat.Type.statusBars()) || insets.isVisible(WindowInsetsCompat.Type.navigationBars())) {
                handler.removeCallbacks(hideNow);
                handler.postDelayed(hideNow, 150);
            }
            return ViewCompat.onApplyWindowInsets(v, insets);
        });
        /* Android viejo: mismo aviso por el camino clásico */
        decor.setOnSystemUiVisibilityChangeListener(vis -> {
            if ((vis & View.SYSTEM_UI_FLAG_FULLSCREEN) == 0 || (vis & View.SYSTEM_UI_FLAG_HIDE_NAVIGATION) == 0) {
                handler.removeCallbacks(hideNow);
                handler.postDelayed(hideNow, 150);
            }
        });
        decor.addOnLayoutChangeListener((v, l, t, r, b, ol, ot, or, ob) -> gestureExclusion(v));
    }

    @Override
    public void onResume() {
        super.onResume();
        resumed = true;
        hideBars();
        handler.removeCallbacks(watch);
        handler.postDelayed(watch, 500);
    }

    @Override
    public void onPause() {
        resumed = false;
        handler.removeCallbacks(watch);
        handler.removeCallbacks(hideNow);
        super.onPause();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) { hideBars(); handler.postDelayed(hideNow, 300); }
    }

    private boolean barsVisible() {
        WindowInsetsCompat ins = ViewCompat.getRootWindowInsets(getWindow().getDecorView());
        if (ins == null) return false;
        return ins.isVisible(WindowInsetsCompat.Type.statusBars()) || ins.isVisible(WindowInsetsCompat.Type.navigationBars());
    }

    /* los controles de manejo están abajo a los costados: ese pedazo de borde no es "atrás" */
    private void gestureExclusion(View v) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return;
        int w = v.getWidth(), h = v.getHeight();
        if (w == 0 || h == 0) return;
        float dp = getResources().getDisplayMetrics().density;
        int edge = (int) (48 * dp), tall = (int) Math.min(h, 200 * dp);
        List<Rect> rects = new ArrayList<>();
        rects.add(new Rect(0, h - tall, edge, h));
        rects.add(new Rect(w - edge, h - tall, w, h));
        v.setSystemGestureExclusionRects(rects);
    }

    /* solo esconder: sin reconfigurar la ventana (eso es lo que hacía titilar) */
    @SuppressWarnings("deprecation")
    private void hideBars() {
        if (ctl != null) ctl.hide(WindowInsetsCompat.Type.systemBars());
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            View d = getWindow().getDecorView();
            int f = View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
            if (d.getSystemUiVisibility() != f) d.setSystemUiVisibility(f);
        }
    }
}
