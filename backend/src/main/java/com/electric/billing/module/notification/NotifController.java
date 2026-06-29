package com.electric.billing.module.notification;

import com.electric.billing.common.R;
import com.electric.billing.entity.Notification;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notification")
public class NotifController {

    private final NotifService notifService;

    public NotifController(NotifService notifService) {
        this.notifService = notifService;
    }

    @GetMapping("/list")
    public R<List<Notification>> list() {
        return R.ok(notifService.listMy());
    }

    @GetMapping("/unread-count")
    public R<Map<String, Long>> unreadCount() {
        return R.ok(Map.of("count", notifService.unreadCount()));
    }

    @PutMapping("/{id}/read")
    public R<?> markRead(@PathVariable Long id) {
        notifService.markRead(id);
        return R.ok();
    }

    @PutMapping("/read-all")
    public R<?> markAllRead() {
        notifService.markAllRead();
        return R.ok();
    }
}
