package com.electric.billing.module.notification;

import com.electric.billing.common.R;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/notification")
public class NotifController {

    private final NotifService notifService;
    public NotifController(NotifService notifService) { this.notifService = notifService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize) {
        return R.ok(notifService.listMy(page, pageSize));
    }

    @GetMapping("/unread-count") public R<Map<String, Long>> unreadCount() { return R.ok(Map.of("count", notifService.unreadCount())); }
    @PutMapping("/{id}/read") public R<?> markRead(@PathVariable Long id) { notifService.markRead(id); return R.ok(); }
    @PutMapping("/read-all") public R<?> markAllRead() { notifService.markAllRead(); return R.ok(); }
}
