package livequiz.zego.com.livequiz.entity;

/**
 * Created by zego on 2018/2/24.
 */

public class ZegoAppIdConfig {

    public long getAppId() {
        return appId;
    }

    public void setAppId(long appId) {
        this.appId = appId;
    }

    public boolean isTestEnv() {
        return isTestEnv;
    }

    public void setTestEnv(boolean testEnv) {
        isTestEnv = testEnv;
    }

    public String getAppIdKey() {
        return appIdKey;
    }

    public void setAppIdKey(String appIdKey) {
        this.appIdKey = appIdKey;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }

    public long appId;
    public boolean isTestEnv;
    public String appIdKey;
    public String userName;




}
