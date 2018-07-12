package livequiz.zego.com.livequiz.dialog;

import android.app.Activity;
import android.content.Context;
import android.support.v7.app.AlertDialog;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;

import livequiz.zego.com.livequiz.R;

/**
 * Created by zego on 2018/2/23.
 */

public class ExitAnswerDialog {

    private Context context;

    public ExitAnswerDialog(Context context) {
        this.context = context;
    }

    public void showExitAnswerDialog() {
        android.support.v7.app.AlertDialog.Builder builder = new android.support.v7.app.AlertDialog.Builder(context, R.style.LoadDialog);
        View view = View
                .inflate(context, R.layout.exit_answer_dialog, null);
        builder.setView(view);
        builder.setCancelable(true);
        final AlertDialog dialog = builder.create();
        view.findViewById(R.id.exit_the_answer).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.cancel();
                ((Activity) context).finish();
            }
        });
        view.findViewById(R.id.continue_the_answer).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                dialog.cancel();
            }
        });
        //获得当前窗体
        Window window = dialog.getWindow();
        //设置为顶部
        WindowManager.LayoutParams lp = window.getAttributes();
        window.setGravity(Gravity.CENTER_HORIZONTAL | Gravity.CENTER_VERTICAL);
        window.setAttributes(lp);
        dialog.show();

    }

}
