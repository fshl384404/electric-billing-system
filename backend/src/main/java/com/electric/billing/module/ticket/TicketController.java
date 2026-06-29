package com.electric.billing.module.ticket;

import com.electric.billing.common.R;
import com.electric.billing.entity.Ticket;
import com.electric.billing.entity.TicketReply;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/ticket")
public class TicketController {

    private final TicketService ticketService;

    public TicketController(TicketService ticketService) {
        this.ticketService = ticketService;
    }

    @GetMapping("/list")
    public R<List<Ticket>> list(@RequestParam(required = false) String status) {
        return R.ok(ticketService.listAll(status));
    }

    @GetMapping("/{id}")
    public R<Ticket> get(@PathVariable Long id) {
        return R.ok(ticketService.getById(id));
    }

    @PostMapping
    public R<Ticket> create(@RequestBody Ticket ticket) {
        return R.ok(ticketService.create(ticket));
    }

    @PostMapping("/{id}/reply")
    public R<TicketReply> reply(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String content = body.get("content");
        if (content == null || content.isEmpty()) {
            return R.fail("回复内容不能为空");
        }
        return R.ok(ticketService.reply(id, content));
    }

    @GetMapping("/{id}/replies")
    public R<List<TicketReply>> replies(@PathVariable Long id) {
        return R.ok(ticketService.listReplies(id));
    }
}
