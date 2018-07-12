package livequiz.zego.com.livequiz.application;


import android.app.Application;
import android.content.Context;
import android.text.TextUtils;
import android.widget.Toast;

import com.zego.zegoliveroom.ZegoLiveRoom;
import com.zego.zegoliveroom.constants.ZegoAvConfig;

import java.io.UnsupportedEncodingException;

import livequiz.zego.com.livequiz.entity.ZegoAppIdConfig;
import livequiz.zego.com.livequiz.utils.AppLogger;
import livequiz.zego.com.livequiz.utils.AppSignKeyUtils;
import livequiz.zego.com.livequiz.utils.PreferenceUtil;
import livequiz.zego.com.livequiz.utils.TimeUtil;


/**
 * des: zego api管理器.
 */
public class ZegoApiManager {

    private static ZegoApiManager sInstance = null;

    private ZegoLiveRoom mZegoLiveRoom = null;

    private ZegoAvConfig mZegoAvConfig = null;

    private long mAppID = 0;
    private byte[] mSignKey = null;

    public String getmUserID() {
        return mUserID;
    }

    public void setmUserID(String mUserID) {
        this.mUserID = mUserID;
    }

    private String mUserID = null;

    private ZegoApiManager() {
        mZegoLiveRoom = new ZegoLiveRoom();
    }

    public static ZegoApiManager getInstance() {
        if (sInstance == null) {
            synchronized (ZegoApiManager.class) {
                if (sInstance == null) {
                    sInstance = new ZegoApiManager();
                }
            }
        }
        return sInstance;
    }

    private void initUserInfo(String mUserID) {

        // 初始化用户信息
        String userName = PreferenceUtil.getInstance().getUserName();
        mUserID = PreferenceUtil.getInstance().getUserID();
        if (TextUtils.isEmpty(mUserID) || TextUtils.isEmpty(userName)) {
            long ms = System.currentTimeMillis();
            mUserID = android.os.Build.MODEL;
            if(TextUtils.isEmpty(mUserID)){
                 mUserID = String.format("%s", TimeUtil.getNowTimeStr());
            }
            userName = mUserID;
            // 保存用户信息
            PreferenceUtil.getInstance().setUserID(mUserID);
            PreferenceUtil.getInstance().setUserName(userName);
        }

        // 必须设置用户信息
        ZegoLiveRoom.setUser(mUserID.replaceAll(" ", ""), userName.replaceAll(" ", ""));

    }


    private void init(Long appID, byte[] signKey, boolean isTestEnv, String mUserID, final ZegoApplication context) {

        initUserInfo(mUserID);
        mZegoLiveRoom.setTestEnv(isTestEnv);

        mAppID = appID;
        mSignKey = signKey;


        ZegoLiveRoom.SDKContext sdkContext = new ZegoLiveRoom.SDKContext() {
            @Override
            public String getSoFullPath() {
                return null;
            }

            @Override
            public String getLogPath() {
                return "/sdcard";
            }

            @Override
            public Application getAppContext() {
                return context;
            }
        };

        mZegoLiveRoom.setSDKContext(sdkContext);

        // 初始化sdk
        boolean ret = mZegoLiveRoom.initSDK(UDP_APP_ID, signData_udp);

        if (!ret) {
            // sdk初始化失败
            Toast.makeText(ZegoApplication.sApplicationContext, "Zego SDK初始化失败!", Toast.LENGTH_LONG).show();
        } else {
            // 初始化设置级别为"High"
            mZegoAvConfig = new ZegoAvConfig(ZegoAvConfig.Level.High);
            mZegoLiveRoom.setAVConfig(mZegoAvConfig);
        }
    }


    /**
     * 初始化sdk.
     */
    public void initSDK(ZegoApplication context) {
        long appIdvalue = PreferenceUtil.getInstance().getAppId();
        if (appIdvalue == -1) {
            PreferenceUtil.getInstance().setAppid(AppSignKeyUtils.UDP_APP_ID);
            PreferenceUtil.getInstance().
                    setAppKey(AppSignKeyUtils.convertSignKey2String(AppSignKeyUtils.requestSignKey(AppSignKeyUtils.UDP_APP_ID)));
        }
        //设置参数
        ZegoAppIdConfig zegoAppIdConfig = new ZegoAppIdConfig();
        zegoAppIdConfig.setAppId(PreferenceUtil.getInstance().getAppId());
        zegoAppIdConfig.setAppIdKey(PreferenceUtil.getInstance().getAppIdKey());
        zegoAppIdConfig.setTestEnv(PreferenceUtil.getInstance().getTestEnv());
        zegoAppIdConfig.setUserName(PreferenceUtil.getInstance().getUserName());

        init(zegoAppIdConfig.getAppId(),signData_udp, zegoAppIdConfig.isTestEnv(), zegoAppIdConfig.getUserName(), context);

    }

    final static public byte[] signData_udp = new byte[]{
            (byte) 0x1e, (byte) 0xc3, (byte) 0xf8, (byte) 0x5c, (byte) 0xb2, (byte) 0xf2, (byte) 0x13, (byte) 0x70,
            (byte) 0x26, (byte) 0x4e, (byte) 0xb3, (byte) 0x71, (byte) 0xc8, (byte) 0xc6, (byte) 0x5c, (byte) 0xa3,
            (byte) 0x7f, (byte) 0xa3, (byte) 0x3b, (byte) 0x9d, (byte) 0xef, (byte) 0xef, (byte) 0x2a, (byte) 0x85,
            (byte) 0xe0, (byte) 0xc8, (byte) 0x99, (byte) 0xae, (byte) 0x82, (byte) 0xc0, (byte) 0xf6, (byte) 0xf8
    };
    static final public long UDP_APP_ID = 1739272706L;

    public void releaseSDK() {
        mZegoLiveRoom.unInitSDK();
    }

    public ZegoLiveRoom getZegoLiveRoom() {
        return mZegoLiveRoom;
    }

    public long getAppID() {
        return mAppID;
    }
}
