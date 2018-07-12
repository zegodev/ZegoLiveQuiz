package livequiz.zego.com.livequiz.activity;


import android.content.Intent;
import android.databinding.DataBindingUtil;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.support.v7.app.AppCompatActivity;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.widget.AdapterView;
import android.widget.CompoundButton;
import android.widget.Toast;


import com.zego.zegoliveroom.ZegoLiveRoom;

import java.io.File;
import java.io.FilenameFilter;

import livequiz.zego.com.livequiz.R;
import livequiz.zego.com.livequiz.application.ZegoApiManager;
import livequiz.zego.com.livequiz.application.ZegoApplication;
import livequiz.zego.com.livequiz.databinding.ActivitySettingsBinding;
import livequiz.zego.com.livequiz.entity.ZegoAppIdConfig;
import livequiz.zego.com.livequiz.utils.AppSignKeyUtils;
import livequiz.zego.com.livequiz.utils.PreferenceUtil;
import livequiz.zego.com.livequiz.utils.ShareUtils;


public class SettingsActivity extends AppCompatActivity {

    private boolean oldUseTestEnvValue;
    private String oldUserName;
    private long oldAppId;
    public ActivitySettingsBinding binding;


    private CompoundButton.OnCheckedChangeListener checkedChangeListener = new CompoundButton.OnCheckedChangeListener() {

        @Override
        public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
            switch (buttonView.getId()) {

                case R.id.checkbox_use_test_env:

                    PreferenceUtil.getInstance().setTestEnv(isChecked);

                    break;
            }
        }
    };


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        binding = DataBindingUtil.setContentView(this, R.layout.activity_settings);


        binding.tvVersion.setText(ZegoLiveRoom.version());


        final Intent startIntent = getIntent();
        binding.spAppFlavor.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {

            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                long appId = 0;
                if (position == 2) {
                    appId = PreferenceUtil.getInstance().getAppId();
                    String signKey = PreferenceUtil.getInstance().getAppIdKey();
                    if (appId > 0 && !TextUtils.isEmpty(signKey)) {
                        binding.etAppId.setText(String.valueOf(appId));
                        binding.etAppKey.setText(signKey);
                    } else {
                        binding.etAppId.setText("");
                        binding.etAppKey.setText("");
                    }

                    binding.etAppId.setEnabled(true);
                    binding.llAppKey.setVisibility(View.VISIBLE);
                } else {
                    switch (position) {
                        case 0:
                            appId = AppSignKeyUtils.UDP_APP_ID;
                            break;

                        case 1:
                            appId = AppSignKeyUtils.INTERNATIONAL_APP_ID;
                            break;
                    }

                    binding.etAppId.setEnabled(false);
                    binding.etAppId.setText(String.valueOf(appId));

                    byte[] signKey = AppSignKeyUtils.requestSignKey(appId);
                    binding.etAppKey.setText(AppSignKeyUtils.convertSignKey2String(signKey));

                    binding.llAppKey.setVisibility(View.GONE);
                }
                setTitle(AppSignKeyUtils.getAppTitle(appId, SettingsActivity.this));
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {

            }
        });

        oldAppId = PreferenceUtil.getInstance().getAppId();
        if (AppSignKeyUtils.isUdpProduct(oldAppId)) {
            binding.spAppFlavor.setSelection(0);

        } else if (AppSignKeyUtils.isInternationalProduct(oldAppId)) {
            binding.spAppFlavor.setSelection(1);

        } else {
            binding.spAppFlavor.setSelection(2);
        }

        binding.tvUserId.setText(PreferenceUtil.getInstance().getUserID());

        oldUserName = PreferenceUtil.getInstance().getUserName();
        binding.tvUserName.setText(oldUserName);

        oldUseTestEnvValue = PreferenceUtil.getInstance().getTestEnv();
        binding.checkboxUseTestEnv.setChecked(oldUseTestEnvValue);

        binding.checkboxUseTestEnv.setOnCheckedChangeListener(checkedChangeListener);


        binding.container.setOnClickListener(new View.OnClickListener() {

            private long[] mHits = new long[5];

            @Override
            public void onClick(View v) {
                System.arraycopy(mHits, 1, mHits, 0, mHits.length - 1);
                mHits[mHits.length - 1] = SystemClock.uptimeMillis();
                if (mHits[0] >= SystemClock.uptimeMillis() - 700) {
                    sendLog2App();
                    for (int i = 0; i < mHits.length; i++) {
                        mHits[i] = 0;
                    }
                }
            }
        });
        binding.atout.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {


                Intent intent = new Intent();
                intent.setAction("android.intent.action.VIEW");
                Uri content_url = Uri.parse("http://www.zego.im");
                intent.setData(content_url);
                startActivity(intent);
            }
        });
    }

    @Override
    public void onBackPressed() {
        String _appIdStr = binding.etAppId.getEditableText().toString();
        String appKey = binding.etAppKey.getEditableText().toString();
        long appId = 0;
        if (!TextUtils.isEmpty(_appIdStr)) {
            try {
                appId = Long.valueOf(_appIdStr);
            } catch (NumberFormatException e) {
                Toast.makeText(this, R.string.zg_tip_appid_format_illegal, Toast.LENGTH_LONG).show();
                binding.etAppId.requestFocus();
                return;
            }
        }

        boolean reInitSDK = false;
        Intent resultIntent = null;
        if (appId != oldAppId) {
            // appKey长度必须等于32位
            byte[] signKey;
            try {
                signKey = AppSignKeyUtils.parseSignKeyFromString(this,appKey);
            } catch (NumberFormatException e) {
                Toast.makeText(this, R.string.zg_tip_appkey_must_32_bits, Toast.LENGTH_LONG).show();
                binding.etAppKey.requestFocus();
                return;
            }

            resultIntent = new Intent();
            resultIntent.putExtra("appId", appId);
            resultIntent.putExtra("signKey", signKey);
            resultIntent.putExtra("rawKey", appKey);
            reInitSDK = true;
        }

        String userName = binding.tvUserName.getEditableText().toString();
        if (!TextUtils.equals(userName, oldUserName)
                && !TextUtils.isEmpty(userName)) {
            PreferenceUtil.getInstance().setUserName(userName);

        }

        PreferenceUtil.getInstance().setAppid(appId);
        PreferenceUtil.getInstance().setAppKey(appKey);

        ZegoApiManager.getInstance().releaseSDK();
        ZegoApiManager.getInstance().initSDK(ZegoApplication.sApplicationContext);

        super.onBackPressed();
    }

    private void sendLog2App() {
        String rootPath = com.zego.zegoavkit2.utils.ZegoLogUtil.getLogPath(this);
        File rootDir = new File(rootPath);
        File[] logFiles = rootDir.listFiles(new FilenameFilter() {
            @Override
            public boolean accept(File dir, String name) {
                return !TextUtils.isEmpty(name) && name.startsWith("zegoavlog") && name.endsWith(".txt");
            }
        });

        if (logFiles.length > 0) {
            ShareUtils.sendFiles(logFiles, this);
        } else {
            Log.w("SettingFragment", "not found any log files.");
        }
    }
}
