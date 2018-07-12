package livequiz.zego.com.livequiz.utils;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Message;
import android.util.Log;

import com.zego.zegoavkit2.utils.ZegoLogUtil;

import java.io.BufferedWriter;
import java.io.Closeable;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.Writer;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;

import livequiz.zego.com.livequiz.application.ZegoApplication;

/**
 * <p>Copyright © 2017 Zego. All rights reserved.</p>
 *
 * @author realuei on 26/10/2017.
 */

public class AppLogger {

    static final private String TAG = "ZEGO_LIVE_QUIZ";

    static final private int MSG_ID_WRITE_LOG = 1;
    static final private int MSG_ID_CLEAR_LOG = 2;

    static final private int SINGLE_LOG_FILE_MAX_SIZE = 10 * 1024 * 1024;   // 10M

    static private String LOG_FILE_NAME = "live_demo_business.log";
    static private String LOG_FILE_NAME_BAK = "live_demo_business_2.log";

    static private AppLogger sInstance;

    final private LinkedList<String> mLogList = new LinkedList<>();
    final private List<String> mUnmodifiableList = Collections.unmodifiableList(mLogList);

    private HandlerThread mLogThread;
    private Handler mLogHandler;

    private ArrayList<OnLogChangedListener> mListeners = new ArrayList<>();

    private File mLogFile;
    private Writer mLogWriter;

    private AppLogger() {
        initLogFile();

        mLogThread = new HandlerThread("live_demo_logger");
        mLogThread.start();

        mLogHandler = new Handler(mLogThread.getLooper()) {

            private int loopCnt = 0;

            @Override
            public void handleMessage(Message msg) {
                switch (msg.what) {
                    case MSG_ID_WRITE_LOG: {
                        flushLogFileIfNeed();

                        String message = (String) msg.obj;

                        Log.d(TAG, message);

                        String message_with_time = String.format("%s %s", TimeUtil.getNowTimeStr(), message);
                        mLogList.addFirst(message_with_time);
                        safeWriteLog2File(message_with_time);

                        for (OnLogChangedListener listener : mListeners) {
                            listener.onLogDataChanged();
                        }
                    }
                    break;

                    case MSG_ID_CLEAR_LOG: {
                        mLogList.clear();
                        for (OnLogChangedListener listener : mListeners) {
                            listener.onLogDataChanged();
                        }
                    }
                    break;
                }

            }

            private void flushLogFileIfNeed() {
                loopCnt++;
                if (loopCnt >= 10) {
                    loopCnt = 0;
                    if (mLogWriter != null) {
                        try {
                            mLogWriter.flush();
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                    }
                }

                int logLength = mLogList.size();
                if (logLength > 1500) {
                    for (int i = logLength - 1; i >= 1000; i--) {
                        mLogList.remove(i);
                    }

                    if (mLogFile.length() >= SINGLE_LOG_FILE_MAX_SIZE) {
                        initLogFile();
                    }
                }
            }
        };
    }

    static public void setLogFileName(String logName, String bakLogName) {
        LOG_FILE_NAME = logName;
        LOG_FILE_NAME_BAK = bakLogName;
    }

    static public AppLogger getInstance() {
        if (sInstance == null) {
            synchronized (AppLogger.class) {
                if (sInstance == null) {
                    sInstance = new AppLogger();
                }
            }
        }
        return sInstance;
    }

    private void initLogFile() {
        String logPath = ZegoLogUtil.getLogPath(ZegoApplication.sApplicationContext);
        File logFile = new File(logPath, LOG_FILE_NAME);
        if (logFile.exists() && logFile.length() >= SINGLE_LOG_FILE_MAX_SIZE) { // 日志文件存在，且文件尺寸大于 10M 时，备份日志
            File bakLogFile = new File(logPath, LOG_FILE_NAME_BAK);
            if (bakLogFile.exists()) {
                bakLogFile.delete();
            }

            safeCloseStream(mLogWriter);
            logFile.renameTo(bakLogFile);
        }

        mLogFile = new File(logPath, LOG_FILE_NAME);
        try {
            safeCloseStream(mLogWriter);

            mLogWriter = new BufferedWriter(new FileWriter(mLogFile, true));
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void safeWriteLog2File(String content) {
        if (mLogWriter == null) return;

        try {
            mLogWriter.write(content);
            mLogWriter.write("\r\n");
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private void safeCloseStream(Closeable stream) {
        if (stream != null) {
            try {
                stream.close();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }

    public void writeLog(Class lclass, final String format, final Object... args) {
        String data;

        if (args.length == 0) {
            data = format;
        } else {
            data = String.format(format, args);
        }

        Message msg = Message.obtain();
        msg.what = MSG_ID_WRITE_LOG;
        msg.obj = lclass.getName() + " :"+data;
        mLogHandler.sendMessage(msg);
    }

    /**
     * 返回只读日志列表
     *
     * @return 只读日志列表
     */
    public List<String> getAllLog() {
        return mUnmodifiableList;
    }

    public void clearLog() {
        mLogHandler.sendEmptyMessage(MSG_ID_CLEAR_LOG);
    }

    public void registerLogChangedListener(final OnLogChangedListener listener) {
        if (listener == null) return;

        mLogHandler.post(new Runnable() {
            @Override
            public void run() {
                boolean inExists = false;
                for (OnLogChangedListener _listener : mListeners) {
                    if (listener == _listener) {
                        inExists = true;
                        break;
                    }
                }

                if (!inExists) {
                    mListeners.add(listener);
                }
            }
        });
    }

    public void unregisterLogChangedListener(final OnLogChangedListener listener) {
        if (listener == null) return;

        mLogHandler.post(new Runnable() {
            @Override
            public void run() {
                int idx = -1;
                for (int i = 0; i < mListeners.size(); i++) {
                    if (mListeners.get(i) == listener) {
                        idx = i;
                        break;
                    }
                }

                if (idx >= 0) {
                    mListeners.remove(idx);
                }
            }
        });
    }

    public interface OnLogChangedListener {
        void onLogDataChanged();
    }
}
