package livequiz.zego.com.livequiz.activity;


import android.databinding.DataBindingUtil;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.v7.widget.DefaultItemAnimator;
import android.support.v7.widget.LinearLayoutManager;

import android.util.Log;
import android.view.View;
import android.widget.Toast;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONArray;

import com.alibaba.fastjson.JSONObject;
import com.tencent.tauth.Tencent;


import java.util.ArrayList;
import java.util.List;

import livequiz.zego.com.livequiz.R;
import livequiz.zego.com.livequiz.adapter.RoomAdapter;
import livequiz.zego.com.livequiz.application.ZegoApiManager;

import livequiz.zego.com.livequiz.databinding.ActivityMainListBinding;
import livequiz.zego.com.livequiz.entity.Room;
import livequiz.zego.com.livequiz.entity.SerializableMap;
import livequiz.zego.com.livequiz.module.ui.ModuleActivity;
import livequiz.zego.com.livequiz.utils.AppLogger;
import livequiz.zego.com.livequiz.utils.ZegoCommon;

/**
 * Created by zego on 2018/1/31.
 */

public class MainActivity extends ModuleActivity implements View.OnClickListener {

    public ActivityMainListBinding binding;
    SerializableMap serializableMap = null;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        //初始化组件
        binding = DataBindingUtil.setContentView(this, R.layout.activity_main_list);
        initView();
        refresh();


    }

    RoomAdapter roomAdapter = new RoomAdapter();

    private void initView() {
        roomAdapter.setOnItemClickListener(new RoomAdapter.OnItemClickListener() {
            @Override
            public void onItemClick(View view, int position) {
                Bundle bundle = new Bundle();
                Room room = (Room) view.getTag();
                bundle.putSerializable("room", room);
                AppLogger.getInstance().writeLog(this.getClass(), "onItemClick room: %s", JSON.toJSON(room));
                stcartActivity(view.getContext(), LiveQuizActivity.class, bundle);
            }
        });

        binding.roomList.setLayoutManager(new LinearLayoutManager(this, LinearLayoutManager.VERTICAL, false));
        // 设置adapter
        binding.roomList.setAdapter(roomAdapter);
        // 设置Item添加和移除的动画
        binding.roomList.setItemAnimator(new DefaultItemAnimator());
        // 设置刷新点击事件
        binding.refresh.setOnClickListener(this);
        // 设置输入房间点击事件
        binding.settings.setOnClickListener(this);


    }


    private void refresh() {
        String url = String.format(ZegoCommon.roomlist, ZegoApiManager.getInstance().getAppID(), ZegoApiManager.getInstance().getAppID());
        AppLogger.getInstance().writeLog(this.getClass(), "refresh url: %s", url);
        //发送请求
        httpUrl(url, "roomList");
    }

    @Override
    public void httpReturn(String body, String red) {
        if (body != null && !"error".equals(body) && "roomList".equals(red)) {
            try {
                AppLogger.getInstance().writeLog(this.getClass(), "httpReturn body:%s", body);
                JSONArray jsonArray = JSON.parseObject(body).getJSONObject("data").getJSONArray("room_list");
                List<Room> roomListValue = JSON.parseArray(jsonArray.toJSONString(), Room.class);
                List<Room> refreshRoomValue = new ArrayList<>();
                roomAdapter.clear();
                for (Room room : roomListValue) {
                    if (room.getStream_info().size() > 0) {
                        AppLogger.getInstance().writeLog(this.getClass(), "httpReturn is quiz roomId:%s  Stream_info:%d", room.getRoom_id(), room.getStream_info().size());
                        refreshRoomValue.add(room);
                    }
                }
                roomAdapter.refreshMsgToRoom(refreshRoomValue);
                if (jsonArray.size() == 0) {
                    binding.prompt.setText(getString(R.string.there_is_no_data_at_the_moment));
                } else {
                    binding.prompt.setText("");
                }
            } catch (Exception e) {
                AppLogger.getInstance().writeLog(this.getClass(), "httpReturn Convert exceptions json:%s", body);
                binding.prompt.setText(getString(R.string.there_is_no_data_at_the_moment));
                e.printStackTrace();
            }
        } else {
            binding.prompt.setText(getString(R.string.there_is_no_data_at_the_moment));
        }
    }


    @Override
    public void onClick(View v) {
        if (binding.refresh.getId() == v.getId()) {
            refresh();
        } else if (binding.settings.getId() == v.getId()) {
            stcartActivity(v.getContext(), SettingsActivity.class, null);

        }
    }


    @Override
    protected void onResume() {
        refresh();
        super.onResume();
    }
}
