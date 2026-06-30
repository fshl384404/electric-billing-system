<template>
  <div>
    <h2><el-icon :size="22" style="vertical-align:middle"><Money /></el-icon> 缴费记录</h2>
    <div style="display:flex;justify-content:space-between;align-items:center;margin:8px 0">
      <el-form :inline="true">
        <el-form-item label="账单ID">
          <el-input-number v-model="billId" :min="1" placeholder="输入账单ID查询" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="fetchList">查询</el-button>
        </el-form-item>
      </el-form>
      <el-button type="success" @click="showOfflineDialog">💵 线下收费</el-button>
    </div>

    <el-table :data="list" border stripe v-loading="loading" max-height="calc(100vh - 230px)">
      <el-table-column prop="paymentId" label="ID" width="80" />
      <el-table-column prop="billId" label="账单ID" width="80" />
      <el-table-column prop="amount" label="金额(元)" width="100" />
      <el-table-column prop="lateFeePaid" label="滞纳金" width="90" />
      <el-table-column prop="channel" label="渠道" width="90">
        <template #default="{ row }">
          <el-tag :type="row.channel === 'ONLINE' ? 'success' : 'warning'" size="small">
            {{ row.channel === 'ONLINE' ? '线上' : '线下' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="payerId" label="缴费人ID" width="90" />
      <el-table-column prop="collectorId" label="收款人ID" width="90" />
      <el-table-column prop="paymentTime" label="缴费时间" width="160" />
      <el-table-column prop="transactionNo" label="流水号" min-width="200" />
    </el-table>

    <el-pagination
      v-model:current-page="currentPage" :page-size="20" :total="total"
      layout="total, prev, pager, next, jumper" @current-change="fetchList"
      style="margin-top:8px;justify-content:flex-end" />

    <!-- 线下收费弹窗 -->
    <el-dialog v-model="offlineVisible" title="💵 线下收费" width="480px">
      <el-form :model="offlineForm" label-width="100px">
        <el-form-item label="账单ID">
          <el-input-number v-model="offlineForm.billId" :min="1" @change="loadBillInfo" />
        </el-form-item>
        <el-form-item label="缴费人ID">
          <el-input-number v-model="offlineForm.payerId" :min="1" />
        </el-form-item>
        <el-form-item label="账单信息" v-if="offlineBillInfo">
          <span>电费: ¥{{ offlineBillInfo.totalAmount }} |
            滞纳金: ¥{{ offlineBillInfo.lateFee || 0 }} |
            状态: <el-tag :type="offlineBillInfo.status==='PAID'?'success':offlineBillInfo.status==='OVERDUE'?'danger':'warning'" size="small">{{ {PENDING:'待缴',PAID:'已缴',OVERDUE:'逾期'}[offlineBillInfo.status] }}</el-tag>
          </span>
        </el-form-item>
        <el-form-item label="应收金额">
          <el-input-number v-model="offlineForm.amount" :min="0" :precision="2" :disabled="!!offlineBillInfo" />
          <span v-if="offlineBillInfo" style="color:#67C23A;margin-left:8px">已锁定: ¥{{ offlineBillInfo.totalAmount + (offlineBillInfo.lateFee||0) }}</span>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="offlineVisible = false">取消</el-button>
        <el-button type="primary" @click="submitOffline" :loading="submitting">确认收款</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import paymentApi from '@/api/payment'
import billApi from '@/api/bill'

const list = ref([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(20)
const billId = ref(null)

onMounted(() => fetchList())

// 线下收费
const offlineVisible = ref(false)
const submitting = ref(false)
const offlineBillInfo = ref(null)
const offlineForm = reactive({ billId: null, payerId: null, amount: 0 })

function showOfflineDialog() {
  offlineForm.billId = null
  offlineForm.payerId = null
  offlineForm.amount = 0
  offlineBillInfo.value = null
  offlineVisible.value = true
}

async function loadBillInfo() {
  if (!offlineForm.billId) { offlineBillInfo.value = null; return }
  try {
    const res = await billApi.get(offlineForm.billId)
    const b = res.data.data
    offlineBillInfo.value = b
    offlineForm.amount = (b.totalAmount || 0) + (b.lateFee || 0)
  } catch { offlineBillInfo.value = null }
}

async function submitOffline() {
  if (!offlineForm.billId) { ElMessage.warning('请填写账单ID'); return }
  if (!offlineForm.payerId) { ElMessage.warning('请填写缴费人ID'); return }
  if (!offlineBillInfo.value) { ElMessage.warning('账单信息未加载，请检查账单ID是否正确'); return }
  if (offlineBillInfo.value?.status === 'PAID') {
    ElMessage.warning('该账单已缴费'); return
  }
  submitting.value = true
  try {
    await paymentApi.pay({
      billId: offlineForm.billId,
      payerId: offlineForm.payerId,
      amount: offlineForm.amount,
      channel: 'OFFLINE'
    })
    ElMessage.success('线下收款成功')
    offlineVisible.value = false
  } finally { submitting.value = false }
}

async function fetchList() {
  loading.value = true
  try {
    const res = await paymentApi.list({ page: currentPage.value, pageSize: pageSize.value, billId: billId.value || undefined })
    list.value = res.data.data.records
    total.value = res.data.data.total
  } finally { loading.value = false }
}
</script>
