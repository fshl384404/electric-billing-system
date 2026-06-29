package com.electric.billing.module.ticket;

import com.electric.billing.common.R;
import com.electric.billing.entity.Ticket;
import com.electric.billing.entity.TicketReply;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/ticket")
public class TicketController {

    private final TicketService ticketService;
    public TicketController(TicketService ticketService) { this.ticketService = ticketService; }

    @GetMapping("/list")
    public R<Map<String, Object>> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int pageSize,
            @RequestParam(required = false) String status) {
        return R.ok(ticketService.listAll(page, pageSize, status));
    }

    @GetMapping("/{id}") public R<Ticket> get(@PathVariable Long id) { return R.ok(ticketService.getById(id)); }
    @PostMapping public R<Ticket> create(@RequestBody Ticket ticket) { return R.ok(ticketService.create(ticket)); }
    @PostMapping("/{id}/reply") public R<TicketReply> reply(@PathVariable Long id, @RequestBody Map<String, String> body) { return R.ok(ticketService.reply(id, body.get("content"))); }
    @GetMapping("/{id}/replies") public R<java.util.List<TicketReply>> replies(@PathVariable Long id) { return R.ok(ticketService.listReplies(id)); }
}
