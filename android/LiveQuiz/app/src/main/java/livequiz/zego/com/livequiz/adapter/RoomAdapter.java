package livequiz.zego.com.livequiz.adapter;

import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;

import java.util.ArrayList;
import java.util.List;

import livequiz.zego.com.livequiz.R;
import livequiz.zego.com.livequiz.entity.Room;


/**
 * Created by zego on 2018/2/6.
 */

public class RoomAdapter extends RecyclerView.Adapter {

    List<Room> roomList = new ArrayList<>();
    private OnItemClickListener mOnItemClickListener;

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View v = LayoutInflater.from(parent.getContext()).inflate(R.layout.room_list, parent, false);

        MyViewHolder viewHolder = new MyViewHolder(v);

        return viewHolder;

    }


    @Override
    public void onBindViewHolder(final RecyclerView.ViewHolder holder, int position) {
        final MyViewHolder myViewHolder = (MyViewHolder) holder;
        if(mOnItemClickListener != null) {
            myViewHolder.on_click.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    if (mOnItemClickListener != null) {
                        int position = myViewHolder.getLayoutPosition();
                        v.setTag(roomList.get(position));
                        mOnItemClickListener.onItemClick(v, position);
                    }
                }
            });
        }

        myViewHolder.room_name.setText(roomList.get(position).getRoom_id());
    }

    @Override
    public int getItemCount() {
        return roomList.size();
    }

    public void refreshMsgToRoom(List<Room> room) {
        roomList.addAll(room);

        notifyDataSetChanged();
    }

    public void clear(){
        roomList.clear();
    }


    public static class MyViewHolder extends RecyclerView.ViewHolder {
        TextView room_name;
        LinearLayout on_click;

        public MyViewHolder(View itemView) {
            super(itemView);
            room_name = itemView.findViewById(R.id.room_name);
            on_click = itemView.findViewById(R.id.on_click);
        }
    }

    public void setOnItemClickListener(OnItemClickListener mOnItemClickListener) {
        this.mOnItemClickListener = mOnItemClickListener;
    }


    public interface OnItemClickListener {
        void onItemClick(View view, int position);
    }


}

