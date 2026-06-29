package com.electric.billing.module.ticket;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.electric.billing.common.BusinessException;
import com.electric.billing.common.PageUtils;
import com.electric.billing.entity.Notification;
import com.electric.billing.entity.Ticket;
import com.electric.billing.entity.TicketReply;
import com.electric.billing.module.notification.NotifMapper;
import com.electric.billing.security.AuthContext;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Date;
import java.util.List;
import java.util.Map;

@Service
public class TicketService {

    private final TicketMapper ticketMapper;
    private final TicketReplyMapper replyMapper;
    private final NotifMapper notifMapper;

    public TicketService(TicketMapper ticketMapper, TicketReplyMapper replyMapper,
                         NotifMapper notifMapper) {
        this.ticketMapper = ticketMapper;
        this.replyMapper = replyMapper;
        this.notifMapper = notifMapper;
    }

    /** 工单列表 — 居民看自己的，管理员/收费员看全部 */
    public Map<String, Object> listAll(int page, int pageSize, String status) {
        LambdaQueryWrapper<Ticket> wrapper = new LambdaQueryWrapper<Ticket>()
                .eq(status != null, Ticket::getStatus, status)
                .orderByDesc(Ticket::getCreatedAt);
        if (AuthContext.isResident()) wrapper.eq(Ticket::getUserId, AuthContext.getCurrentUserId());
        return PageUtils.paginate(ticketMapper, wrapper, page, pageSize);
    }

    /** 工单详情 */
    public Ticket getById(Long id) {
        Ticket ticket = ticketMapper.selectById(id);
        if (ticket == null) {
            throw new BusinessException("工单不存在");
        }
        if (AuthContext.isResident() && !ticket.getUserId().equals(AuthContext.getCurrentUserId())) {
            throw new BusinessException(403, "无权查看");
        }
        return ticket;
    }

    /** 居民提交工单 */
    public Ticket create(Ticket ticket) {
        if (!AuthContext.isResident()) {
            throw new BusinessException("仅居民可提交工单");
        }
        ticket.setTicketId(ticketMapper.nextId());
        ticket.setUserId(AuthContext.getCurrentUserId());
        ticket.setStatus("PENDING");
        ticket.setCreatedAt(new Date());
        ticketMapper.insert(ticket);
        return ticket;
    }

    /** 回复工单 — 事务: insert reply + update ticket + insert notification */
    @Transactional
    public TicketReply reply(Long ticketId, String content) {
        if (AuthContext.isResident()) {
            throw new BusinessException(403, "无权限回复工单");
        }

        Ticket ticket = ticketMapper.selectById(ticketId);
        if (ticket == null) {
            throw new BusinessException("工单不存在");
        }
        if ("REPLIED".equals(ticket.getStatus())) {
            throw new BusinessException("该工单已回复");
        }

        // 1. 插入回复
        TicketReply reply = new TicketReply();
        reply.setReplyId(replyMapper.nextId());
        reply.setTicketId(ticketId);
        reply.setReplierId(AuthContext.getCurrentUserId());
        reply.setContent(content);
        reply.setCreatedAt(new Date());
        replyMapper.insert(reply);

        // 2. 更新工单状态
        ticket.setStatus("REPLIED");
        ticket.setRepliedBy(AuthContext.getCurrentUserId());
        ticket.setRepliedAt(new Date());
        ticketMapper.updateById(ticket);

        // 3. 通知工单提交人
        Notification notif = new Notification();
        notif.setNotifId(notifMapper.nextId());
        notif.setUserId(ticket.getUserId());
        notif.setType("TICKET_REPLY");
        notif.setTitle("工单回复通知");
        notif.setContent("您的工单「" + ticket.getTitle() + "」已收到回复");
        notif.setRelatedId(ticketId);
        notif.setIsRead("N");
        notif.setCreatedAt(new Date());
        notifMapper.insert(notif);

        return reply;
    }

    /** 查看工单的回复列表 */
    public List<TicketReply> listReplies(Long ticketId) {
        return replyMapper.selectList(
                new LambdaQueryWrapper<TicketReply>()
                        .eq(TicketReply::getTicketId, ticketId)
                        .orderByAsc(TicketReply::getCreatedAt)
        );
    }
}
